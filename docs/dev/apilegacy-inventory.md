# apilegacy 保留清单

Kratos 迁移已完成，`internal/apilegacy/` 仍承担**运行时兼容层**，暂不可整包删除。

## 仍被引用的模块

| 路径 | 用途 | 迁移方向 |
|------|------|----------|
| `config/` | 启动期 `Config` 结构体，与 `config/config.yaml` 合并 | 逐步迁入 `internal/platform/yamlconf` |
| `common/jwtctx.go` | JWT 上下文辅助 | 迁入 `internal/server/auth` |
| `common/llm_inference_client.go` | LLM 推理 HTTP 客户端 | 迁入 `internal/biz/llm` |
| `common/local_models.go` | 本地模型目录 | 迁入 `internal/biz/llm` |
| `common/admin_*.go` | 管理端转换/审计辅助 | 迁入 `internal/biz/admin` |
| `moebridge/` | proto 与 biz 结构转换 | 与 `internal/biz/admin/adminv1_out.go` 合并 |
| `swaggerdoc/` | Swagger UI 静态页 | 保留或迁至 `internal/server/http_docs.go` |
| `presence/` | 在线状态（chat 兼容） | 迁入 `internal/biz/chat` |

## 配置统一

- **SSOT**：`backend/config/config.yaml`
- **合并入口**：`internal/platform/wiring/config_override.go` → `apilegacy/config.Config`
- **待移除**：`utils/db.go` 内独立 viper 路径（已去掉硬编码绝对路径；新代码禁止 `utils.GetDB()`）

## 删除条件

当以下条件全部满足时可删 `apilegacy/`：

1. 启动只读 `yamlconf` / Kratos config，不再构造 `apilegacy/config.Config`
2. protohttp 不再 import `apilegacy/common`
3. `grep -r apilegacy backend/internal` 仅剩文档引用
