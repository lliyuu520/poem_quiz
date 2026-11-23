# 部署到 ECS（无 Docker）

目标环境：内存小的自有阿里云 ECS，已购买 Redis 服务。全部用系统级
二进制 + systemd，不引入容器。

**当前生产状态**（2026-11-23 已部署）：

| 项 | 值 |
|---|---|
| ECS | 8.137.17.235（内网 172.20.197.242），cn-chengdu，Debian 12，1.7GB 内存 |
| Redis | `r-2vc3zpodcefj0pztqh.redis.cn-chengdu.rds.aliyuncs.com:6379`（v7.0，256MB，VPC 同交换机） |
| 域名 | `shi-api.lliyuu520.cn`（泛域名证书） |
| 二进制 | `/opt/shi-account/shi-account`，8.0MB 静态链接 |
| 服务 | systemd `shi-account`，监听 `127.0.0.1:8080` |
| 实测内存 | 8.2MB RSS |
| nginx | `/etc/nginx/conf.d/shi-api.conf` + `nginx-ratelimit.conf` |

## 前提

- ECS 与 Redis 实例在**同一 VPC**（本例同 vpc 同 vswitch，内网直连）
- Redis 白名单需加 ECS 内网 IP（本例 `172.20.197.242`）
- 服务只监听 `127.0.0.1:8080`，由 nginx 反代对外提供 HTTPS
- 一个非 root 运行账号

## 1. 本地交叉编译

```bash
cd server
./build.sh          # → server/shi-account，约 8MB 静态链接
```

产物是 `statically linked`，不依赖目标机上的 glibc 版本。

## 2. 传到服务器

```bash
ssh <user>@<ecs-host> 'sudo mkdir -p /opt/shi-account'
scp server/shi-account <user>@<ecs-host>:/tmp/
```

## 3. 服务器上安装

```bash
# 建运行账号（无登录 shell）
sudo useradd -r -s /sbin/nologin shi || true

sudo mv /tmp/shi-account /opt/shi-account/
sudo chown -R shi:shi /opt/shi-account
sudo chmod 755 /opt/shi-account/shi-account

# systemd unit
sudo cp server/deploy/shi-account.service /etc/systemd/system/
# 按实际情况改 REDIS_ADDR / REDIS_PASSWORD（阿里云 Redis 实例信息）
sudo systemctl daemon-reload
sudo systemctl enable --now shi-account

# 验证
curl -s http://127.0.0.1:8080/healthz
journalctl -u shi-account -n 30 --no-pager
```

## 4. nginx 反代（HTTPS）

只反代到回环，并把请求体限制在存档上限附近：

```nginx
server {
    listen 443 ssl http2;
    server_name shi-api.example.com;

    ssl_certificate     /etc/letsencrypt/live/shi-api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/shi-api.example.com/privkey.pem;

    # 存档上限 256KB，留出 JSON 包装余量
    client_max_body_size 512k;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
        # 登录接口按 IP 限流，防口令爆破
        limit_req zone=shi_api burst=3 nodelay;
        limit_req_status 429;
    }
}
```

zone 定义（实测值）：

```
limit_req_zone $binary_remote_addr zone=shi_api:10m rate=2r/m;
```

**为什么是 2r/m 而不是 5r/s**：最初配 `5r/s + burst=5`，实测连发 8 次登录
全部返回 401（限流没触发）——5r/s 加 5 个突发，等于短时间能放过 10 个请求，
对爆破几乎没有阻挡。登录是人工操作，正常人不会一秒点两次，所以收紧到
`2r/m`（每 30 秒补一个令牌）+ `burst=3`。实测：连发 8 次时第 2 次起返回
429，等 35 秒后恢复正常。

调整限流参数后必须实测，`nginx -t` 通过不代表限流真的拦得住。

## 升级

```bash
cd server && ./build.sh
scp shi-account <user>@<ecs-host>:/tmp/
ssh <user>@<ecs-host> '
  sudo systemctl stop shi-account &&
  sudo mv /tmp/shi-account /opt/shi-account/ &&
  sudo chown shi:shi /opt/shi-account/shi-account &&
  sudo systemctl start shi-account &&
  curl -s http://127.0.0.1:8080/healthz'
```

停机窗口只有启动那一下（毫秒级），Redis 里的会话与存档不受影响。

## 内存占用参考

- 二进制 8MB（磁盘）
- 常驻内存 8.2MB（实测，Go 运行时 + 几个连接）
- 无容器开销、无 JVM 堆预留

## 本机 nginx 的两个坑（2026-11-23 实测）

**1. `sites-enabled/` 不生效。** 这台机器的 `nginx.conf` 只 include
`conf.d/*.conf`，没有 include `sites-enabled/`（Debian 默认会 include，
这台被改过）。站点文件要放 `/etc/nginx/conf.d/`，否则 `nginx -t` 通过、
`systemctl reload` 也成功，但配置根本没加载——表现为 HTTPS 请求被
`catchall.conf` 的 `default_server` 接走并 `return 444`（curl 报空响应
`exit=52`）。**排查方法**：`nginx -T | grep "server_name 你的域名"`，
查不到就是没加载。

**2. `catchall.conf` 是 443 的 `default_server`，`return 444`。**
所有未匹配的域名直接断连。所以新站点的 `server_name` 必须精确匹配，
且配置必须真的被加载（见上一条）。

## 不要做的事

- 不要用 Docker / docker-compose：这台机器内存小，容器守护进程与镜像层
  的额外开销没必要。
- 不要把 Redis 暴露公网，也不要给 Go 服务加 `0.0.0.0` 监听。
- 不要把 Redis 密码写进 unit 文件的 `Environment=` 然后提交到仓库——
  实际值放 `/opt/shi-account/env`（`640 root:shi`），unit 用
  `EnvironmentFile` 引用。这样 `systemctl cat` 与 journal 都不会泄露密码。
