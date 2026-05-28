# vip.v1 — VIP 套餐契约（PK-1 SSOT）

| RPC | 生产 HTTP（:8888） | 试点 HTTP（:19032） |
|-----|-------------------|---------------------|
| `ListPlans` | `GET /api/admin/vip/plans` | 同左（`RegisterVipCompat`） |

灰度：`moe.kratos_vip_http_enabled: true` → `vipadmingw` 的 `ListPlans` 走 `kratos_http`。

生成：`make gen-moe-proto`
