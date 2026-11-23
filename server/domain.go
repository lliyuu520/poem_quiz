package main

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"
)

// 领域层：账号与存档的业务规则。这一层不碰 Redis，便于单测。

var (
	ErrUsernameTaken      = errors.New("用户名已被占用")
	ErrUserNotFound       = errors.New("用户不存在")
	ErrBadCredentials     = errors.New("用户名或密码不正确")
	ErrWeakPassword       = errors.New("密码至少 8 位")
	ErrBadUsername        = errors.New("用户名需 3~20 位字母、数字或下划线")
	ErrSaveNotFound       = errors.New("该科目还没有云端存档")
	ErrVersionConflict    = errors.New("云端存档已被其他设备更新")
)

var usernamePattern = regexp.MustCompile(`^[A-Za-z0-9_]{3,20}$`)

const (
	minPasswordLen = 8
	// maxSaveBytes 是单科目存档的大小上限。现有存档只有几十个 id 的 JSON，
	// 给到 256KB 足够宽松；设上限是为了防止误传大文件撑爆 Redis。
	maxSaveBytes = 256 * 1024
)

// Credentials 是注册/登录的输入。
type Credentials struct {
	Username string
	Password string
}

// Validate 检查用户名与密码格式。密码不做复杂度要求——这是自用服务，
// 强制大小写混排只会让用户写便利贴。
func (c Credentials) Validate() error {
	if !usernamePattern.MatchString(c.Username) {
		return ErrBadUsername
	}
	if utf8.RuneCountInString(c.Password) < minPasswordLen {
		return ErrWeakPassword
	}
	return nil
}

// User 是写入 Redis 的账号记录。
type User struct {
	Username     string `json:"username"`
	PasswordHash string `json:"passwordHash"`
	CreatedAt    int64  `json:"createdAt"`
}

// Save 是一个科目在某设备上传的存档。
//
// Version 用于乐观并发：客户端上传时带上自己看到的版本号，服务端版本
// 不是它期望的就拒绝，避免两台设备互相覆盖。存档是 JSON 原文照存，
// 服务端不解析其结构——题库与存档格式都在 App 侧演进，服务端跟着改
// 只会把自己和客户端版本绑死。
type Save struct {
	TopicID   string `json:"topicId"`
	Version   int64  `json:"version"`
	UpdatedAt int64  `json:"updatedAt"`
	Payload   string `json:"payload"`
}

// DeviceLabel 从 User-Agent 里截出一段可读的设备标识，用于在设置页
// 显示「上次同步来自哪台设备」。取不到就返回空串，不编造。
func DeviceLabel(ua string) string {
	ua = strings.TrimSpace(ua)
	if ua == "" {
		return ""
	}
	if utf8.RuneCountInString(ua) > 80 {
		ua = string([]rune(ua)[:80])
	}
	return ua
}

// key 辅助：集中定义 Redis 键前缀，避免各处手拼字符串时拼错。
func userKey(username string) string { return "user:" + strings.ToLower(username) }
func saveKey(username, topicID string) string {
	return fmt.Sprintf("save:%s:%s", strings.ToLower(username), topicID)
}
func tokenKey(token string) string { return "token:" + token }
