# OpenAPI 文档与 Apifox 同步

> **更新：2026-05-29**  
> 契约 SSOT：`api/**/v1/*.proto` → **OpenAPI 3.0.3** `backend/openapi.yaml`

## 产物

| 项目 | 说明 |
|------|------|
| 生成文件 | `backend/openapi.yaml` |
| 本地文档 | `http://127.0.0.1:8888/swagger/openapi.yaml` |
| 生成命令 | `make gen` 或 `make gen-swagger` |

**已删除**：`rest.swagger.json`（Swagger 2.0 / goctl）、`api/defs/*.api`。

## 导入 Apifox

1. `cd backend && make gen`
2. Apifox → 导入 → OpenAPI → 选择 `backend/openapi.yaml`
3. 环境变量 `baseUrl` = `http://127.0.0.1:8888`

或 URL 导入（服务已启动）：`http://127.0.0.1:8888/swagger/openapi.yaml`

## 覆盖范围

| 来源 | 进入 openapi.yaml |
|------|-------------------|
| `api/**/v1/*.proto` + `google.api.http` | ✅ |
| `internal/server/transport/`（OAuth/WS/SSE） | ❌ 待补 proto 注解 |

## 相关

- [new-api-kratos.md](./new-api-kratos.md)
- `scripts/gen/openapi.sh`
