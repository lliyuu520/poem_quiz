package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
)

// 服务入口。配置全部走环境变量，不读配置文件——这个服务只有几个参数，
// 配置文件反而是额外的部署负担。
//
//	REDIS_ADDR      默认 127.0.0.1:6379
//	REDIS_PASSWORD  默认空
//	REDIS_DB        默认 0
//	LISTEN_ADDR     默认 :8080
//	SESSION_TTL     默认 720h（30 天）
func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	addr := env("REDIS_ADDR", "127.0.0.1:6379")
	db := 0
	if v := os.Getenv("REDIS_DB"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 0 {
			log.Error("REDIS_DB 需为非负整数", "value", v)
			os.Exit(1)
		}
		db = n
	}
	rdb := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: os.Getenv("REDIS_PASSWORD"),
		DB:       db,
	})

	// 启动时探一次 Redis：连不上就立刻退出，别等到第一个请求才报错。
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Error("Redis 连接失败", "addr", addr, "err", err)
		os.Exit(1)
	}

	ttl := 720 * time.Hour
	if v := os.Getenv("SESSION_TTL"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			ttl = d
		}
	}

	srv := &http.Server{
		Addr:              env("LISTEN_ADDR", ":8080"),
		Handler:           NewServer(NewStore(rdb, ttl), log).Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	// 优雅停机：收到信号后不再接新连接，给在途请求 10 秒收尾。
	idle := make(chan struct{})
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
		<-sig
		log.Info("收到停止信号，开始优雅停机")
		shutdownCtx, done := context.WithTimeout(context.Background(), 10*time.Second)
		defer done()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Error("停机超时", "err", err)
		}
		close(idle)
	}()

	log.Info("服务启动", "addr", srv.Addr, "redis", addr, "sessionTTL", ttl.String())
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Error("监听失败", "err", err)
		os.Exit(1)
	}
	<-idle
	log.Info("已停止")
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
