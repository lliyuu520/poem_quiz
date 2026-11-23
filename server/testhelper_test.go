package main

import (
	"io"
	"log/slog"
)

// discardLogger 给测试用：不打印日志，避免测试输出被 access log 淹没。
func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}
