# admin.v1 — Admin Insights（PK-3）

| HTTP（:8888 / :19032 同路径） | 灰度 |
|------------------------------|------|
| `GET /api/admin/ai/chat/sessions` | `kratos_admin_insights_http_enabled` |
| `GET /api/admin/ai/chat/messages` | 或 `kratos_pilot_read_enabled` |
| `GET /api/admin/ai/chat/messages/export` | |
| `GET /api/admin/analytics/overview` | |
| `GET /api/admin/topic-tags` | |

试点注册：`api/moekratospilot/admin_insights_compat.go`
