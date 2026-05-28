# API 契约

## 新接口（必读）

**新 HTTP 能力**：只加 `api/<domain>/v1/*.proto`，**禁止**扩大 `api/defs/*.api`。

→ [docs/dev/new-api-kratos.md](../../docs/dev/new-api-kratos.md)

```bash
make gen              # 生成 *.pb.go
# 实现 internal/service + internal/biz
# 注册 api/moehttp/*_compat.go
make check && make moe-social
```

## 存量 goctl（维护老接口）

| 步骤 | 命令 |
|------|------|
| 改 `api/defs/*.api` | `make gen-api` |
| 写逻辑 | `api/internal/logic/<group>/*logic.go` |
| Kratos 路由同步 | 自动 `gen-http-routes` |

## 域 proto 索引

| 域 | Proto | HTTP 注册 |
|----|-------|-----------|
| Moe Admin | [moe/v1/moe.proto](./moe/v1/moe.proto) | `api/moehttp/admin_compat.go` |
| VIP 只读 | [vip/v1/vip_read.proto](./vip/v1/vip_read.proto) | `api/moehttp/vip_compat.go` |
| Admin Insights | [admin/v1/admin_insights.proto](./admin/v1/admin_insights.proto) | `api/moehttp/admin_insights_compat.go` |
| LLM / AI / Chat | [llm/v1/](./llm/v1/) 等 | 灰度 / 存量 logic |

## 相关

- [LAYOUT.md](../LAYOUT.md)
- [scripts/README.md](../scripts/README.md)
