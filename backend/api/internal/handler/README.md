# api/internal/handler — 生产壳

> HTTP 业务在 `internal/server/httplegacy/*_compat.go` 或 `http_proto.go`；本目录仅 hybrid 残留。

| 文件 | 作用 |
|------|------|
| `doc/` | `/swagger` UI 与 `doc.json` |
| `routes_stub.go` | 空 `RegisterHandlers`（兼容 goctl 生成引用） |

路由表归档：`scripts/gen/http-routes/fixtures/routes.go`
