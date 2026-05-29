# api/internal/handler — 生产壳

> HTTP 业务在 `api/moehttp/*_compat.go`；本目录仅保留 Swagger。

| 文件 | 作用 |
|------|------|
| `doc/` | `/swagger` UI 与 `doc.json` |
| `routes_stub.go` | 空 `RegisterHandlers`（兼容 goctl 生成引用） |

路由表归档：`scripts/gen/http-routes/fixtures/routes.go`
