# backend/rpc/ 已删除（2026-05-29）

生产唯一路径：`cmd/moe-social` → Kratos HTTP `:8888`（`api/<domain>/v1/*.proto` + `make gen`）。

原 `rpc/` 职责迁移：

| 原路径 | 现路径 |
|--------|--------|
| `rpc/internal/bootstrap/social_hooks.go` | `internal/platform/bootstrap/social_hooks.go` |
| `rpc/internal/bootstrap/scheduler.go` | `internal/platform/bootstrap/scheduler.go` |
| `rpc/runserver/`（gRPC :8080） | 已移除；`moe.http_only: true` 为唯一生产模式 |
| `rpc/defs/services/*.rpcfrag` | 本目录 `defs/services/`（只读归档） |
| `rpc/moe.proto` | 本目录 `moe.proto`（只读归档） |

契约 SSOT：`api/<domain>/v1/*.proto` → `openapi.yaml`。
