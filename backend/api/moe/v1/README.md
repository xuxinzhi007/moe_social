# moe.v1 — Moe Admin 域契约（PK-1 SSOT）

| RPC | 生产 HTTP（:8888，go-zero） | 试点 HTTP（:19032，moekratos） |
|-----|---------------------------|-------------------------------|
| `ListRuntimes` | `GET /api/admin/moe/runtimes` | 同左（`RegisterAdminCompat`） |
| `GetBrainPipeline` | `GET /api/admin/moe/brain/pipeline?agent_key=` | 同左 |

灰度：`config.yaml` → `moe.kratos_admin_http_enabled: true` 且 `make moe-kratos` 运行时，`:8888` 的上述读接口经 `moeadmingw` → `kratos_http`。

生成：`make gen-moe-proto`
