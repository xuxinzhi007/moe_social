# 用 VPS 把内网 SSH 映射到 2222

内网 Linux 没有公网 IP 时，在内网机器上做反向隧道，把本机 `22` 挂到云主机 `2222`。客户端不用装 Tailscale / frp。

```text
ssh -p 2222 内网用户@云IP  →  云:2222  →  内网:22
```

云上的 `22` 仍用来登录云本身，不要占用。

占位符：`云IP`、`内网用户`。不要把真实 IP、密码发到公网。

## 云主机

安全组放行 TCP **2222**。

Ubuntu 服务名是 `ssh` 不是 `sshd`：

```bash
echo 'GatewayPorts clientspecified' | tee -a /etc/ssh/sshd_config
systemctl reload ssh || systemctl restart ssh
grep GatewayPorts /etc/ssh/sshd_config
```

应有一行未被注释的 `GatewayPorts clientspecified`。

## 内网机器

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id root@云IP
ssh root@云IP echo ok
```

`Are you sure...` 输入 `yes`。密码是云 root，无回显。成功输出 `Number of key(s) added: 1`。  
`Connection closed` 一般是密码错误，再执行一次 `ssh-copy-id`。

`echo ok` 不再要密码之后：

```bash
sudo tee /etc/systemd/system/ssh-jump.service << 'EOF'
[Unit]
Description=Reverse SSH to VPS :2222
After=network-online.target

[Service]
User=内网用户
ExecStart=/usr/bin/ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:2222:127.0.0.1:22 root@云IP
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ssh-jump
sudo systemctl status ssh-jump --no-pager
```

`User=` 和 `root@云IP` 换成真实值。状态须为 `active (running)`。

## 登录

在**另一台电脑**上：

```powershell
ssh -p 2222 内网用户@云IP
```

用户名、密码都是内网机器的。不要在内网本机测 2222：服务未起来时云上无人监听，会 `Connection refused`。

首次连接若提示指纹已对应内网局域网 IP，说明转到了内网机，输入 `yes`。

## 故障

| 现象 | 处理 |
|------|------|
| `reload sshd` 失败 | `systemctl reload ssh` |
| 2222 `Connection refused` | `systemctl status ssh-jump`；检查安全组 |
| 进去的是云主机 | 端口写成了 22，或用户名用了 root |
| 时断时续 | 内网关机/掉线；`journalctl -u ssh-jump -n 50` |

`ssh-copy-id` 一直失败时，用云厂商网页终端：

```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo '内网 cat ~/.ssh/id_ed25519.pub 的整行' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

## 和 frp / Tailscale

- SSH 回家、客户端零安装：本文。
- 把家里 HTTP/API 转到云 IP：frp（勿与本文抢 2222）。
- 自己设备组网：Tailscale。

只映射 SSH。不要把面板、数据库、Ollama 端口对 `0.0.0.0/0` 放开。
