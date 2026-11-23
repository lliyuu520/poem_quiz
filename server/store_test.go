package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

// storeTest 起一个内存 Redis 并返回 Store。miniredis 支持 Lua，
// 所以并发校验脚本能在测试里真实跑到。
func storeTest(t *testing.T) (*Store, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = rdb.Close() })
	return NewStore(rdb, time.Hour), mr
}

func mustRegister(t *testing.T, s *Store, name, pass string) {
	t.Helper()
	if _, err := s.Register(context.Background(), Credentials{name, pass}); err != nil {
		t.Fatalf("注册 %s 失败: %v", name, err)
	}
}

func TestRegisterAndLogin(t *testing.T) {
	s, _ := storeTest(t)
	ctx := context.Background()

	if _, err := s.Register(ctx, Credentials{"kid", "password123"}); err != nil {
		t.Fatalf("首次注册应成功: %v", err)
	}
	// 同名再注册必须失败，否则会静默覆盖别人（或自己）的密码。
	if _, err := s.Register(ctx, Credentials{"kid", "other12345"}); err != ErrUsernameTaken {
		t.Fatalf("重名注册应返回 ErrUsernameTaken，实际 %v", err)
	}

	token, err := s.Authenticate(ctx, Credentials{"kid", "password123"})
	if err != nil {
		t.Fatalf("登录应成功: %v", err)
	}
	if token == "" {
		t.Fatal("token 不该为空")
	}
	name, err := s.Resolve(ctx, token)
	if err != nil {
		t.Fatalf("解析 token 失败: %v", err)
	}
	if name != "kid" {
		t.Fatalf("token 应解析出 kid，实际 %s", name)
	}
}

func TestLoginWrongPassword(t *testing.T) {
	s, _ := storeTest(t)
	mustRegister(t, s, "kid", "password123")

	// 密码错与用户不存在要返回同一个错误，避免暴露用户名是否存在。
	if _, err := s.Authenticate(context.Background(), Credentials{"kid", "wrongpass1"}); err != ErrBadCredentials {
		t.Fatalf("密码错误应返回 ErrBadCredentials，实际 %v", err)
	}
	if _, err := s.Authenticate(context.Background(), Credentials{"nobody", "password123"}); err != ErrBadCredentials {
		t.Fatalf("用户不存在应返回 ErrBadCredentials，实际 %v", err)
	}
}

func TestValidateRules(t *testing.T) {
	cases := []struct {
		name string
		c    Credentials
		want error
	}{
		{"正常", Credentials{"abc", "12345678"}, nil},
		{"用户名太短", Credentials{"ab", "12345678"}, ErrBadUsername},
		{"用户名带中文", Credentials{"小明", "12345678"}, ErrBadUsername},
		{"用户名太长", Credentials{"abcdefghijklmnopqrstu", "12345678"}, ErrBadUsername},
		{"密码太短", Credentials{"abc", "1234567"}, ErrWeakPassword},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := tc.c.Validate(); got != tc.want {
				t.Fatalf("Validate() = %v, 期望 %v", got, tc.want)
			}
		})
	}
}

func TestTokenRevokedByLogout(t *testing.T) {
	s, _ := storeTest(t)
	ctx := context.Background()
	mustRegister(t, s, "kid", "password123")
	token, _ := s.Authenticate(ctx, Credentials{"kid", "password123"})

	if _, err := s.Resolve(ctx, token); err != nil {
		t.Fatalf("登出前应可解析: %v", err)
	}
	if err := s.Logout(ctx, token); err != nil {
		t.Fatalf("登出应成功: %v", err)
	}
	// 这正是不用 JWT 的好处：登出后 token 立即失效，不需要等过期。
	if _, err := s.Resolve(ctx, token); err != ErrBadCredentials {
		t.Fatalf("登出后应失效，实际 %v", err)
	}
}

func TestTokenExpires(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()
	s := NewStore(rdb, time.Hour)
	ctx := context.Background()
	mustRegister(t, s, "kid", "password123")

	token, _ := s.Authenticate(ctx, Credentials{"kid", "password123"})
	mr.FastForward(2 * time.Hour)
	if _, err := s.Resolve(ctx, token); err != ErrBadCredentials {
		t.Fatalf("过期后应失效，实际 %v", err)
	}
}

// ── 存档 ──

func TestSaveRoundTrip(t *testing.T) {
	s, _ := storeTest(t)
	ctx := context.Background()
	mustRegister(t, s, "kid", "password123")

	// 首次上传：期望版本 0（云端还没有）。
	got, err := s.PutSave(ctx, "kid", Save{TopicID: "poetry", Payload: `{"best":1}`}, 0)
	if err != nil {
		t.Fatalf("首次上传应成功: %v", err)
	}
	if got.Version != 1 {
		t.Fatalf("首次上传版本应为 1，实际 %d", got.Version)
	}

	read, err := s.GetSave(ctx, "kid", "poetry")
	if err != nil {
		t.Fatalf("读取失败: %v", err)
	}
	if read.Payload != `{"best":1}` {
		t.Fatalf("payload 不一致: %s", read.Payload)
	}
}

func TestSaveVersionConflict(t *testing.T) {
	s, _ := storeTest(t)
	ctx := context.Background()
	mustRegister(t, s, "kid", "password123")

	// 两台设备都从版本 0 起，第一台成功后版本变 1。
	if _, err := s.PutSave(ctx, "kid", Save{TopicID: "poetry", Payload: `{"a":1}`}, 0); err != nil {
		t.Fatalf("设备 A 上传应成功: %v", err)
	}
	// 第二台仍以为云端是 0，必须被拒，否则会覆盖 A 的进度。
	cur, err := s.PutSave(ctx, "kid", Save{TopicID: "poetry", Payload: `{"b":2}`}, 0)
	if err != ErrVersionConflict {
		t.Fatalf("版本不匹配应冲突，实际 %v", err)
	}
	if cur == nil || cur.Payload != `{"a":1}` {
		t.Fatalf("冲突时应返回云端现有存档，实际 %+v", cur)
	}

	// 拿到新版本后再传就成功。
	if _, err := s.PutSave(ctx, "kid", Save{TopicID: "poetry", Payload: `{"b":2}`}, 1); err != nil {
		t.Fatalf("带正确版本应成功: %v", err)
	}
}

func TestSaveIsolatedPerUser(t *testing.T) {
	s, _ := storeTest(t)
	ctx := context.Background()
	mustRegister(t, s, "kid", "password123")
	mustRegister(t, s, "mom", "password456")

	if _, err := s.PutSave(ctx, "kid", Save{TopicID: "poetry", Payload: `{"x":1}`}, 0); err != nil {
		t.Fatal(err)
	}
	// 别的账号读同一个科目不该看到别人的存档。
	if _, err := s.GetSave(ctx, "mom", "poetry"); err != ErrSaveNotFound {
		t.Fatalf("跨账号应读不到，实际 %v", err)
	}
}

func TestSaveSizeLimit(t *testing.T) {
	s, _ := storeTest(t)
	mustRegister(t, s, "kid", "password123")
	big := make([]byte, maxSaveBytes+1)
	if _, err := s.PutSave(context.Background(),
		"kid", Save{TopicID: "poetry", Payload: string(big)}, 0); err == nil {
		t.Fatal("超大存档应被拒")
	}
}

// ── HTTP 端到端 ──

func httpTestServer(t *testing.T) (*httptest.Server, *Store) {
	t.Helper()
	s, _ := storeTest(t)
	srv := httptest.NewServer(NewServer(s, discardLogger()).Routes())
	t.Cleanup(srv.Close)
	return srv, s
}

func TestHTTPAuthFlow(t *testing.T) {
	srv, _ := httpTestServer(t)

	post := func(path string, body any) *http.Response {
		b, _ := json.Marshal(body)
		resp, err := http.Post(srv.URL+path, "application/json", bytes.NewReader(b))
		if err != nil {
			t.Fatal(err)
		}
		return resp
	}

	resp := post("/api/register", Credentials{"kid", "password123"})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("注册应 201，实际 %d", resp.StatusCode)
	}
	resp.Body.Close()

	resp = post("/api/login", Credentials{"kid", "password123"})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("登录应 200，实际 %d", resp.StatusCode)
	}
	var login struct {
		Token string `json:"token"`
	}
	json.NewDecoder(resp.Body).Decode(&login)
	resp.Body.Close()
	if login.Token == "" {
		t.Fatal("登录应返回 token")
	}

	// 无 token 访问存档必须 401。
	resp, _ = http.Get(srv.URL + "/api/saves")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("无 token 应 401，实际 %d", resp.StatusCode)
	}
	resp.Body.Close()

	// 带 token 正常访问。
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/api/saves", nil)
	req.Header.Set("Authorization", "Bearer "+login.Token)
	resp, _ = http.DefaultClient.Do(req)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("带 token 应 200，实际 %d", resp.StatusCode)
	}
	resp.Body.Close()
}

func TestHTTPSaveWithIfMatch(t *testing.T) {
	srv, _ := httpTestServer(t)
	post := func(path string, body any) *http.Response {
		b, _ := json.Marshal(body)
		resp, _ := http.Post(srv.URL+path, "application/json", bytes.NewReader(b))
		return resp
	}
	post("/api/register", Credentials{"kid", "password123"}).Body.Close()
	resp := post("/api/login", Credentials{"kid", "password123"})
	var login struct {
		Token string `json:"token"`
	}
	json.NewDecoder(resp.Body).Decode(&login)
	resp.Body.Close()

	put := func(ifMatch, payload string) *http.Response {
		body, _ := json.Marshal(map[string]string{"payload": payload})
		req, _ := http.NewRequest(http.MethodPut, srv.URL+"/api/saves/poetry", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+login.Token)
		if ifMatch != "" {
			req.Header.Set("If-Match", ifMatch)
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		return resp
	}

	if r := put("", `{"v":1}`); r.StatusCode != http.StatusOK {
		t.Fatalf("首次 PUT 应 200，实际 %d", r.StatusCode)
	} else {
		r.Body.Close()
	}
	// 用过期版本号再传，必须 409 且带回云端存档。
	r := put("0", `{"v":2}`)
	if r.StatusCode != http.StatusConflict {
		t.Fatalf("版本过期应 409，实际 %d", r.StatusCode)
	}
	var conflict struct {
		Error   string `json:"error"`
		Current *Save  `json:"current"`
	}
	json.NewDecoder(r.Body).Decode(&conflict)
	r.Body.Close()
	if conflict.Current == nil || conflict.Current.Payload != `{"v":1}` {
		t.Fatalf("409 应带回云端存档，实际 %+v", conflict.Current)
	}
}
