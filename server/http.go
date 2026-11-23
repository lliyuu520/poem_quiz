package main

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
)

// HTTP 层：路由、鉴权、错误映射。业务规则都在 Store/domain 里。

type Server struct {
	store *Store
	log   *slog.Logger
}

func NewServer(store *Store, log *slog.Logger) *Server {
	return &Server{store: store, log: log}
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/register", s.handleRegister)
	mux.HandleFunc("POST /api/login", s.handleLogin)
	mux.HandleFunc("POST /api/logout", s.withAuth(s.handleLogout))
	mux.HandleFunc("GET /api/saves", s.withAuth(s.handleListSaves))
	mux.HandleFunc("GET /api/saves/{topic}", s.withAuth(s.handleGetSave))
	mux.HandleFunc("PUT /api/saves/{topic}", s.withAuth(s.handlePutSave))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	return s.recoverer(mux)
}

// ── 错误映射 ──

// errStatus 把领域错误映射成 HTTP 状态码。集中在一处，避免每个 handler
// 里各写一遍 switch 而漏掉某个分支。
func errStatus(err error) (int, string) {
	switch {
	case errors.Is(err, ErrBadUsername), errors.Is(err, ErrWeakPassword):
		return http.StatusBadRequest, err.Error()
	case errors.Is(err, ErrUsernameTaken):
		return http.StatusConflict, err.Error()
	case errors.Is(err, ErrBadCredentials):
		return http.StatusUnauthorized, err.Error()
	case errors.Is(err, ErrSaveNotFound):
		return http.StatusNotFound, err.Error()
	case errors.Is(err, ErrVersionConflict):
		return http.StatusConflict, err.Error()
	default:
		return http.StatusInternalServerError, "服务器内部错误"
	}
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, err error) {
	code, msg := errStatus(err)
	writeJSON(w, code, map[string]string{"error": msg})
}

// ── 鉴权中间件 ──

// withAuth 从 Authorization: Bearer <token> 取 token 并解析出用户名。
// 用户名通过 context 往下传，不放在请求头里（那等于让客户端自称身份）。
func (s *Server) withAuth(next func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := bearer(r)
		username, err := s.store.Resolve(r.Context(), token)
		if err != nil {
			writeErr(w, ErrBadCredentials)
			return
		}
		next(w, r, username)
	}
}

func bearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if len(h) > len(prefix) && strings.EqualFold(h[:len(prefix)], prefix) {
		return strings.TrimSpace(h[len(prefix):])
	}
	return ""
}

// ── handlers ──

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var c Credentials
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&c); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "请求体不是合法 JSON"})
		return
	}
	u, err := s.store.Register(r.Context(), c)
	if err != nil {
		writeErr(w, err)
		return
	}
	s.log.Info("注册成功", "username", u.Username)
	writeJSON(w, http.StatusCreated, map[string]any{
		"username":  u.Username,
		"createdAt": u.CreatedAt,
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var c Credentials
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&c); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "请求体不是合法 JSON"})
		return
	}
	token, err := s.store.Authenticate(r.Context(), c)
	if err != nil {
		// 登录失败只记用户名，不记密码，也不记 token。
		s.log.Warn("登录失败", "username", c.Username)
		writeErr(w, err)
		return
	}
	s.log.Info("登录成功", "username", c.Username, "token", fingerprint(token))
	writeJSON(w, http.StatusOK, map[string]any{
		"token":     token,
		"expiresIn": int(s.store.session.Seconds()),
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request, username string) {
	if err := s.store.Logout(r.Context(), bearer(r)); err != nil {
		writeErr(w, err)
		return
	}
	s.log.Info("登出", "username", username)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleListSaves(w http.ResponseWriter, r *http.Request, username string) {
	saves, err := s.store.ListSaves(r.Context(), username)
	if err != nil {
		writeErr(w, err)
		return
	}
	if saves == nil {
		saves = []Save{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"saves": saves})
}

func (s *Server) handleGetSave(w http.ResponseWriter, r *http.Request, username string) {
	topic := r.PathValue("topic")
	save, err := s.store.GetSave(r.Context(), username, topic)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, save)
}

func (s *Server) handlePutSave(w http.ResponseWriter, r *http.Request, username string) {
	topic := r.PathValue("topic")

	// If-Match 承载客户端手中的版本号；缺省视为 0（新建）。
	expected := int64(0)
	if v := r.Header.Get("If-Match"); v != "" {
		n, err := strconv.ParseInt(v, 10, 64)
		if err != nil || n < 0 {
			writeJSON(w, http.StatusBadRequest,
				map[string]string{"error": "If-Match 需为非负整数版本号"})
			return
		}
		expected = n
	}

	var body struct {
		Payload string `json:"payload"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxSaveBytes+4096)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "请求体不是合法 JSON"})
		return
	}

	saved, err := s.store.PutSave(r.Context(), username,
		Save{TopicID: topic, Payload: body.Payload}, expected)
	if errors.Is(err, ErrVersionConflict) {
		// 冲突时把云端存档一起返回，客户端可据此让用户选或自动合并。
		writeJSON(w, http.StatusConflict, map[string]any{
			"error":   ErrVersionConflict.Error(),
			"current": saved,
		})
		return
	}
	if err != nil {
		writeErr(w, err)
		return
	}
	s.log.Info("存档已更新", "username", username, "topic", topic, "version", saved.Version)
	writeJSON(w, http.StatusOK, saved)
}

// recoverer 兜住 handler 里的 panic，避免单个请求打挂整个进程。
func (s *Server) recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				s.log.Error("panic", "path", r.URL.Path, "err", rec)
				writeJSON(w, http.StatusInternalServerError,
					map[string]string{"error": "服务器内部错误"})
			}
		}()
		next.ServeHTTP(w, r)
	})
}

