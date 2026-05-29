# gRPC 冒烟 — notify / chat / vip

> **最后更新：2026-05-29**  
> **端口 SSOT**：`config/config.yaml` → `runtime.grpc_listen`（默认 `0.0.0.0:8080`）

---

## 前置

1. 服务已启动：`cd backend && make moe-social`（或分体 RPC 监听 `:8080`）。
2. 安装 [grpcurl](https://github.com/fullstorydev/grpcurl)（`go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest` 或包管理器）。
3. 在 **backend 仓库根**（`backend/`）执行下列命令，以便 `-import-path api` 解析 proto。

**反射**：gRPC reflection 仅在 RPC `Mode=dev|test` 时注册（见 `rpc/runserver/kratos.go`）。生产/默认 pro 模式请用 **-proto** 路径（下文脚本默认走 proto）。

---

## Go 测试（推荐 CI / 本地）

```bash
cd backend && make moe-social   # 另开终端
GRPC_SMOKE=1 go test ./internal/platform/grpcsmoke/... -count=1 -v
```

---

## 一键脚本

| 平台 | 命令 |
|------|------|
| Linux / macOS / Git Bash | `cd backend && bash scripts/grpc-smoke-notify-chat-vip.sh` |
| Windows PowerShell | `cd backend; .\scripts\grpc-smoke-notify-chat-vip.ps1` |

环境变量：

| 变量 | 默认 | 说明 |
|------|------|------|
| `GRPC_HOST` | `127.0.0.1:8080` | gRPC 地址 |
| `SMOKE_USER_ID` | `1` | 请求里的 `user_id` / `viewer_id`（须为数字用户 ID） |

---

## 手工 grpcurl（proto 模式）

### 列出已注册服务（需 dev 反射）

```bash
grpcurl -plaintext 127.0.0.1:8080 list
```

### notify.v1.NotifyService

```bash
cd backend
grpcurl -plaintext \
  -import-path api -proto api/notify/v1/notify.proto \
  -d '{"user_id":"smoke-user-1","page":1,"page_size":5}' \
  127.0.0.1:8080 notify.v1.NotifyService/GetNotifications

grpcurl -plaintext \
  -import-path api -proto api/notify/v1/notify.proto \
  -d '{"user_id":"smoke-user-1"}' \
  127.0.0.1:8080 notify.v1.NotifyService/GetUnreadCount
```

### chat.v1.PrivateMessageService

```bash
grpcurl -plaintext \
  -import-path api -proto api/chat/v1/private_message.proto \
  -d '{"viewer_id":"1","limit":10,"offset":0}' \
  127.0.0.1:8080 chat.v1.PrivateMessageService/ListPrivateConversations
```

### vip.v1.VipService

```bash
grpcurl -plaintext \
  -import-path api -proto api/vip/v1/vip.proto \
  -d '{"user_id":"smoke-user-1","page":1,"page_size":5}' \
  127.0.0.1:8080 vip.v1.VipService/GetVipRecords

grpcurl -plaintext \
  -import-path api -proto api/vip/v1/vip.proto \
  -d '{"user_id":"smoke-user-1"}' \
  127.0.0.1:8080 vip.v1.VipService/GetUserActiveVipRecord
```

---

## 期望结果

| RPC | 成功判据 |
|-----|----------|
| `GetNotifications` | gRPC `OK`（可为空列表） |
| `GetUnreadCount` | `count` 字段存在（≥0） |
| `ListPrivateConversations` | `OK`（可为空） |
| `GetVipRecords` / `GetUserActiveVipRecord` | `OK`（无活跃 VIP 时 `record` 可为空） |

失败时优先检查：进程是否监听 `:8080`、Postgres/迁移是否就绪、proto import 路径是否以 `backend/` 为 cwd。

---

## 与 P5 的关系

- 冒烟目标为 **P4 独立域 gRPC**（`NotifyService` / `PrivateMessageService` / `VipService`），**不是** 已删除的 `super.Super`。
- 分体部署配置见 [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md)。
