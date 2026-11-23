#!/usr/bin/env bash
# 交叉编译 Linux 单二进制（无 CGO，无 Docker）。
# 产物可直接 scp 到 ECS 运行，不需要任何运行时依赖。
set -euo pipefail
cd "$(dirname "$0")"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w" -trimpath -o shi-account .
echo "产物: $(pwd)/shi-account"
ls -lh shi-account | awk '{print "大小:", $5}'
