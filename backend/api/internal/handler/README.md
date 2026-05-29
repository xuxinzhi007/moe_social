# api/internal/handler — 生产壳

> HTTP 业务在 `internal/server/httplegacy/*_compat.go` 或 `http_proto.go`；本目录仅 hybrid 残留。

| 文件 | 作用 |
|------|------|
| `routes_stub.go` | 空 `RegisterHandlers`（兼容 goctl 生成引用） |

## API 文档（OpenAPI 3.0）

运行时由 `internal/apilegacy/swaggerdoc/` 提供（非本目录 `doc/`）：

| URL | 说明 |
|-----|------|
| `/swagger` | Swagger UI |
| `/swagger/openapi.yaml` | OpenAPI 3.0.3 规范（**Apifox 推荐导入此地址或本地文件**） |
| `/swagger/doc.json` | 兼容旧地址 |

生成与 Apifox 导入：[docs/dev/openapi-apifox.md](../../../docs/dev/openapi-apifox.md)。

路由表归档（`gen-http-routes` 输入）：`scripts/gen/http-routes/fixtures/routes.go`
