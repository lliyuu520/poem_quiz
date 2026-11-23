package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"

	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

// Store 把账号、令牌与存档操作集中在 Redis 上。
//
// 会话用「不透明随机 token + Redis 键」而不是 JWT：可以随时踢下线、
// token 本身不含任何用户信息，撤销就是 DEL 一个键。
type Store struct {
	rdb     *redis.Client
	session time.Duration
}

func NewStore(rdb *redis.Client, sessionTTL time.Duration) *Store {
	return &Store{rdb: rdb, session: sessionTTL}
}

// Register 创建账号。用户名比较不区分大小写（key 里已转小写）。
func (s *Store) Register(ctx context.Context, c Credentials) (*User, error) {
	if err := c.Validate(); err != nil {
		return nil, err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(c.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	u := &User{
		Username:     c.Username,
		PasswordHash: string(hash),
		CreatedAt:    time.Now().Unix(),
	}
	body, err := json.Marshal(u)
	if err != nil {
		return nil, err
	}
	// SetNX 保证并发注册同名时只有一个成功，不需要先查再写（那有竞态）。
	ok, err := s.rdb.SetNX(ctx, userKey(c.Username), body, 0).Result()
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrUsernameTaken
	}
	return u, nil
}

// Authenticate 校验密码，成功则签发新 token。
func (s *Store) Authenticate(ctx context.Context, c Credentials) (string, error) {
	raw, err := s.rdb.Get(ctx, userKey(c.Username)).Result()
	if errors.Is(err, redis.Nil) {
		return "", ErrBadCredentials
	}
	if err != nil {
		return "", err
	}
	var u User
	if err := json.Unmarshal([]byte(raw), &u); err != nil {
		return "", err
	}
	// 用户不存在与密码错误返回同一个错误，避免暴露出「这个用户名存在」。
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(c.Password)) != nil {
		return "", ErrBadCredentials
	}
	return s.issueToken(ctx, u.Username)
}

func (s *Store) issueToken(ctx context.Context, username string) (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	token := base64.RawURLEncoding.EncodeToString(buf)
	if err := s.rdb.Set(ctx, tokenKey(token), username, s.session).Err(); err != nil {
		return "", err
	}
	return token, nil
}

// Resolve 由 token 反查用户名。找不到说明过期或已登出。
func (s *Store) Resolve(ctx context.Context, token string) (string, error) {
	if token == "" {
		return "", ErrBadCredentials
	}
	name, err := s.rdb.Get(ctx, tokenKey(token)).Result()
	if errors.Is(err, redis.Nil) {
		return "", ErrBadCredentials
	}
	if err != nil {
		return "", err
	}
	return name, nil
}

// Logout 删除 token。token 不存在也视为成功（幂等）。
func (s *Store) Logout(ctx context.Context, token string) error {
	return s.rdb.Del(ctx, tokenKey(token)).Err()
}

// PutSave 写入一个科目的存档。
//
// expectedVersion 是客户端手里的版本：0 表示「我认为云端还没有存档」。
// 版本不匹配时返回 ErrVersionConflict，并把当前云端存档一并带回，
// 让客户端决定覆盖还是保留本地，而不是静默丢掉一方进度。
//
// 版本号由服务端维护（当前版本 +1），客户端不能自定——否则并发校验
// 就失去意义了。
func (s *Store) PutSave(ctx context.Context, username string, save Save, expectedVersion int64) (*Save, error) {
	if len(save.Payload) > maxSaveBytes {
		return nil, errors.New("存档过大")
	}
	if save.TopicID == "" {
		return nil, errors.New("缺少科目 id")
	}

	key := saveKey(username, save.TopicID)

	// Lua 脚本一次原子完成「读当前 → 校验版本 → 写新版本」，避免两台设备
	// 同时上传时都读到旧版本、都写成功。
	// KEYS[1]=存档键  ARGV[1]=期望版本 ARGV[2]=payload
	// 返回 {status, payload 或空}
	const script = `
local cur = redis.call('GET', KEYS[1])
local curVer = 0
local curRaw = ''
if cur then
  local ok, decoded = pcall(cjson.decode, cur)
  if ok and decoded.version then curVer = tonumber(decoded.version) end
  curRaw = cur
end
local want = tonumber(ARGV[1])
if want ~= curVer then
  return {'conflict', curRaw}
end
local nextVer = curVer + 1
local now = tonumber(ARGV[3])
local payload = {}
payload.topicId = ARGV[4]
payload.version = nextVer
payload.updatedAt = now
payload.payload = ARGV[2]
redis.call('SET', KEYS[1], cjson.encode(payload))
return {'ok', cjson.encode(payload)}
`
	res, err := s.rdb.Eval(ctx, script, []string{key},
		expectedVersion, save.Payload,
		time.Now().Unix(), save.TopicID).Result()
	if err != nil {
		return nil, err
	}
	arr, ok := res.([]interface{})
	if !ok || len(arr) != 2 {
		return nil, errors.New("Lua 返回格式异常")
	}
	status, _ := arr[0].(string)
	body, _ := arr[1].(string)

	if status == "conflict" {
		if body != "" {
			var cur Save
			if json.Unmarshal([]byte(body), &cur) == nil {
				return &cur, ErrVersionConflict
			}
		}
		return nil, ErrVersionConflict
	}

	var stored Save
	if err := json.Unmarshal([]byte(body), &stored); err != nil {
		return nil, err
	}
	return &stored, nil
}

// GetSave 读一个科目的存档。
func (s *Store) GetSave(ctx context.Context, username, topicID string) (*Save, error) {
	raw, err := s.rdb.Get(ctx, saveKey(username, topicID)).Result()
	if errors.Is(err, redis.Nil) {
		return nil, ErrSaveNotFound
	}
	if err != nil {
		return nil, err
	}
	var sv Save
	if err := json.Unmarshal([]byte(raw), &sv); err != nil {
		return nil, err
	}
	return &sv, nil
}

// ListSaves 列出该用户所有科目的存档摘要（不含 payload）。
func (s *Store) ListSaves(ctx context.Context, username string) ([]Save, error) {
	pattern := saveKey(username, "*")
	var out []Save
	iter := s.rdb.Scan(ctx, 0, pattern, 100).Iterator()
	for iter.Next(ctx) {
		raw, err := s.rdb.Get(ctx, iter.Val()).Result()
		if err != nil {
			continue
		}
		var sv Save
		if json.Unmarshal([]byte(raw), &sv) == nil {
			sv.Payload = ""
			out = append(out, sv)
		}
	}
	return out, iter.Err()
}

// fingerprint 用于日志脱敏：只记录 token 的短哈希，不落明文。
func fingerprint(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:4])
}
