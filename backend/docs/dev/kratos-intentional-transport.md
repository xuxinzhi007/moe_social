# Kratos intentional transport（7 条）

> **状态**：有意保留，不计入 D2 compat 债务。  
> **注册入口**：`internal/server/http_intentional_transport.go` → `httplegacy.Register*Compat`

## 路由清单

| 类 | 条数 | 路径 | 原因 | 长期方案 |
|----|------|------|------|----------|
| OAuth | 2 | `/api/auth/feishu/callback`, `/api/auth/wechat/callback` | 浏览器重定向，非 JSON RPC | 保留 Kratos `Route()`；authorize/login 已 proto HTTP |
| SSE | 1 | `/api/admin/moe/brain/pipeline/stream` | `google.api.http` 无标准 SSE | 保留 net/http stream；或 gRPC server-stream |
| WebSocket | 4 | chat WS 四入口 | Upgrade 握手 | 保留 `httplegacy/chat_ws_compat.go`；REST presence 已 proto |

## 已迁入 proto HTTP

| 域 | 条数 | 路径 | 说明 |
|----|------|------|------|
| media/v1 | 4 | `/api/images*`, `/api/upload` | `api/media/v1/media.proto` + `mediagrpc.RegisterHTTPServer`（multipart 上传 + 二进制 ServeContent） |

## 架构原则（Kratos 官方）

1. **默认**：`api/<domain>/v1/*.proto` + `google.api.http` → `Register*HTTPServer`（`http_proto.go`）
2. **例外**：仅 transport 限制（OAuth 重定向、WS Upgrade、SSE）走 `RegisterIntentionalTransportHTTP`
3. **禁止**：在 `httplegacy` 新增 JSON CRUD compat；新能力只加 proto HTTP

## 残留旧方法（勿再使用）

| 已退役 | 替代 |
|--------|------|
| `RegisterCompatHTTP` | `RegisterIntentionalTransportHTTP` |
| `RegisterNativeDomainHTTPHandlers`（空壳） | `RegisterProtoHTTP` |
| `RegisterBridgeHTTPHandlers` | `RegisterDocsHTTP`（Swagger） |
| `rpc/pb/moe` / `moe_bridge` | `api/*/v1` 域 proto |
| `TotalGoZeroRoutes` | `TotalHTTPRoutes` |
| `wave2_misc_compat.go` | `api/media/v1` + `internal/server/grpc/media` |
