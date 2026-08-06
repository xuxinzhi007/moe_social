# apilegacy 退役说明

> **2026-08-06**：`internal/apilegacy/` 已物理删除；能力迁入下列包。

| 原路径 | 新路径 | 包名 |
|--------|--------|------|
| `apilegacy/config/` | `internal/platform/apiconfig/` | `apiconfig` |
| `apilegacy/common/` | `internal/platform/apicomm/` | `apicomm` |
| `apilegacy/moebridge/` | `internal/biz/moe/moebridge/` | `moebridge` |
| `apilegacy/swaggerdoc/` | `internal/server/swaggerdoc/` | `doc` |
| `apilegacy/presence/` | 删除（直用 `internal/pkg/presence`） | — |

## 配置

- **SSOT**：`backend/config/config.yaml`
- **API 片段**：`api/etc/moe.yaml` → `apiconfig.Config`（经 `yamlconf` + `wiring.ApplyUnifiedConfigOverrides`）
- **DB 访问**：生产 wiring / bootstrap 使用 `internal/platform/appdb.Open()`；禁止新代码调用 `utils.GetDB()`

## 后续可继续收敛

- `apicomm` 中 JWT/admin 辅助可再迁入 `internal/server/auth` / `internal/biz/admin`
- LLM client / local models 可再迁入 `internal/biz/llm`
- `utils/db.go` 全局单例可再收口到 data 层显式注入
