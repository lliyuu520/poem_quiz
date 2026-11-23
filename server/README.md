# 拾 · 账号与云存档服务

自用账号服务：注册、登录、多科目存档同步。Go + Redis，单二进制部署。

**当前状态**：本地开发完成，未部署。App 端接入尚未开始。

## 为什么不用 JWT

会话用「不透明随机 token + Redis 键」：

```
登录 → 随机 32 字节 token → SET token:<token> <username> EX 720h
请求 → 查 Redis 拿 username
登出 → DEL token:<token>
```

好处是能随时踢下线、token 不含任何用户信息、撤销就是删一个键。JWT 的
无状态优势在这个规模（一个家庭几个账号）没有价值，而无法主动失效是硬伤。

## 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/register` | `{username, password}` → 201 |
| POST | `/api/login` | `{username, password}` → `{token, expiresIn}` |
| POST | `/api/logout` | Bearer token → 204 |
| GET | `/api/saves` | 列出各科目存档摘要（不含 payload） |
| GET | `/api/saves/{topic}` | 读某科目存档 |
| PUT | `/api/saves/{topic}` | 写存档，`If-Match: <version>` |
| GET | `/healthz` | 健康检查 |

### 存档并发控制

版本号由**服务端**维护（当前 +1），客户端不能自定。上传时用 `If-Match`
带上手里的版本：

- 云端没有存档 → `If-Match: 0`
- 版本不匹配 → `409`，响应体里的 `current` 是云端现有存档

这样两台设备不会互相静默覆盖，客户端可以选「保留本地」或「用云端」。
判定与写入在同一个 Lua 脚本里完成，避免读-改-写之间的竞态。

**服务端不解析存档结构**，`payload` 原样存字符串。题库与存档格式都在 App
侧演进，服务端跟着解析只会把两端版本绑死。

## 配置

全部走环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `REDIS_ADDR` | `127.0.0.1:6379` | Redis 地址 |
| `REDIS_PASSWORD` | 空 | Redis 密码 |
| `REDIS_DB` | `0` | Redis 库号 |
| `LISTEN_ADDR` | `:8080` | 监听地址 |
| `SESSION_TTL` | `720h` | 会话有效期 |

## 本地开发

```bash
cd server
go test ./...              # 用 miniredis，不需要真 Redis
go run .                   # 需要本地 Redis
```

## 构建与部署

```bash
cd server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o shi-account
# 产物约 15MB，scp 到 ECS 即可运行
```

Redis 用阿里云 Redis 服务时，把 `REDIS_ADDR`、`REDIS_PASSWORD` 写成内网
地址与实例密码。**不要把 Redis 暴露公网**。

## 待办

- [ ] App 端登录页与同步逻辑
- [ ] 学习分析埋点（现有 ProgressStore 只有聚合计数，无逐题记录）
- [ ] 部署到 ECS
