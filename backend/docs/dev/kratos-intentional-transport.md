# Kratos transport HTTP（7 条）

> **状态**：与 proto HTTP 同进程、同 `make gen` 管理；非 JSON 响应的 transport 层。  
> **注册入口**：`internal/server/http_transport.go` → `transport.RegisterHTTP`

## 路由清单

| 类 | 条数 | 路径 | 实现 |
|----|------|------|------|
| OAuth | 2 | `/api/auth/feishu/callback`, `/api/auth/wechat/callback` | `transport/oauth.go` |
| WebSocket | 4 | `/ws/chat`, `/ws/presence`, `/ws/remote`, `/ws/world` | `transport/websocket.go` |
| SSE | 1 | `/api/admin/moe/brain/pipeline/stream` | `transport/sse.go` |

OAuth 的 authorize/login 等 JSON 接口已在 `api/user/v1` proto HTTP。

## HTTP 装配（唯一入口）

```text
NewHTTPServer (internal/server/http.go)
  → RegisterOpsHTTP
  → RegisterProtoHTTP        # api/**/v1/*_http.pb.go
  → RegisterDocsHTTP         # /swagger
  → RegisterTransportHTTP    # OAuth / WS / SSE
```

## `make gen` 链路

```text
make gen
  → gen-moe-proto            # api/**/v1/*.proto → *.pb.go / *_http.pb.go
  → gen-moe-conf
  → gen-proto-route-count    # 统计 *_http.pb.go → routestats/proto_routes_gen.go
```

## 已退役

| 旧路径 | 替代 |
|--------|------|
| `internal/server/httplegacy/` | `transport/` + `routestats/` |
| `wave2_misc_compat.go` | `api/media/v1` + `grpc/media` |
| `scripts/gen/http-routes/` | `scripts/gen/proto-route-count/` |
| `rpc/pb/moe` | `api/*/v1` |
