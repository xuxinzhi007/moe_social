# moe.v1 — Moe Admin 域契约

| RPC | HTTP |
|-----|------|
| `ListRuntimes` | `GET /api/admin/moe/runtimes` |
| `GetBrainPipeline` | `GET /api/admin/moe/brain/pipeline?agent_key=` |

SSE 流水线：`GET /api/admin/moe/brain/pipeline/stream`（`internal/server/transport`，非 proto JSON）。

生成：`cd backend && make gen`
