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
  → gen-moe-proto            # 固定版本预检 → pb/grpc/http → openapi.yaml
make check-gen              # 独立临时生成，只读比较当前工作树产物
```

## 已退役

| 旧路径 | 替代 |
|--------|------|
| `internal/conf/moe/v1` + `gen-moe-conf` | 无（唯一导入方 `moeconf` 已整包删除；配置 SSOT 为 `pkg/conf`） |
| `internal/server/httplegacy/` | `transport/` |
| `wave2_misc_compat.go` | `api/media/v1` + `grpc/media` |
| `scripts/gen/http-routes/`、`scripts/gen/proto-route-count/`、`internal/server/routestats/` | 无；静态生成函数计数不能代表实际注册路由 |
| `rpc/pb/moe` | `api/*/v1` |
