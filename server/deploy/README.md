# 部署到 ECS（无 Docker）

目标环境：内存小的自有阿里云 ECS，已购买 Redis 服务。全部用系统级
二进制 + systemd，不引入容器。

## 前提

- ECS 上已装 Redis（或用阿里云 Redis 实例）
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
        limit_req zone=api burst=10 nodelay;
    }
}
```

在 `http {}` 里配一个 `limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;`。

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
- 常驻内存约 10~15MB（Go 运行时 + 几个连接）
- 无容器开销、无 JVM 堆预留

## 不要做的事

- 不要用 Docker / docker-compose：这台机器内存小，容器守护进程与镜像层
  的额外开销没必要。
- 不要把 Redis 暴露公网，也不要给 Go 服务加 `0.0.0.0` 监听。
- 不要把 Redis 密码写进 unit 文件的 `Environment=` 然后提交到仓库——
  这个 unit 文件是模板，实际值在服务器上填。
