"""本地 HTTPS 代理：把模拟器的 cdn.jsdelivr.net 请求转发到 PC 网络栈。

adb reverse tcp:18443 tcp:443 只能转 TCP，TLS 由模拟器端发起时 SNI 仍是
cdn.jsdelivr.net，而 PC 端 443 上的真实服务就是 jsDelivr，所以直接
TCP 转发是透明的——但模拟器把域名解析到 127.0.0.1 需要改 hosts，
模拟器未 root 做不到。

替代方案：App 里把 manifestUrl 的域名换成 10.0.2.2:18443（模拟器访问
宿主机环回的专用地址），配合 adb reverse tcp:18443 tcp:443，
TLS 握手由 PC 侧 connect 到 cdn.jsdelivr.net:443 完成，证书是
cdn.jsdelivr.net 的原始证书，App 校验通过。
这只用于本机调试；正式包仍然直连 cdn.jsdelivr.net。
"""

import socket
import threading
import sys

REMOTE = ('cdn.jsdelivr.net', 443)
LISTEN = ('127.0.0.1', 18443)


def pipe(a: socket.socket, b: socket.socket):
    try:
        while True:
            data = a.recv(65536)
            if not data:
                break
            b.sendall(data)
    except OSError:
        pass
    finally:
        try:
            b.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client: socket.socket):
    try:
        server = socket.create_connection(REMOTE, timeout=10)
    except OSError as e:
        print('connect fail:', e)
        client.close()
        return
    t1 = threading.Thread(target=pipe, args=(client, server), daemon=True)
    t2 = threading.Thread(target=pipe, args=(server, client), daemon=True)
    t1.start()
    t2.start()
    t1.join()
    t2.join()
    client.close()
    server.close()


def main():
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(LISTEN)
    srv.listen(16)
    print(f'listening {LISTEN} -> {REMOTE}')
    while True:
        c, _ = srv.accept()
        threading.Thread(target=handle, args=(c,), daemon=True).start()


if __name__ == '__main__':
    main()
