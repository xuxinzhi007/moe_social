# API 契约（PK-1 纪律）

> **对外 HTTP**：Kratos `:8888`，路由注册在 `api/moehttp`；`api/<domain>/v1/*.proto` 为域 SSOT。

## 规则（PK-1 起强制）

1. **新接口** → 只加 `api/<domain>/v1/*.proto`，**禁止**扩大 `api/defs/common.api` 巨石。
2. **HTTP 路径** 在 proto 顶部用注释写明，须与现有 `moe.api` 路径 **完全一致**。
3. **实现** → `internal/biz/<domain>` + `internal/service/<domain>`。
4. **灰度** → `config/config.yaml` 的 `moe.kratos_*_http_enabled`。

## 生成

```bash
cd backend
make gen-moe-proto      # api/**/v1/*.proto → *.pb.go
make gen-moe-conf       # internal/conf
make gen-http-routes    # routes.go → api/moehttp
```

改 `moe.api` 后（需 `MOE_ALLOW_GOCTL_API=1`）：`make gen-api`，会自动 `gen-http-routes`。

## 域索引

| 域 | Proto | Kratos HTTP 注册 |
|----|-------|------------------|
| Moe Admin | [moe/v1/moe.proto](./moe/v1/moe.proto) | `moehttp` AdminCompat |
| VIP 只读 | [vip/v1/vip_read.proto](./vip/v1/vip_read.proto) | `RegisterVipCompat` |
| Admin Insights | [admin/v1/admin_insights.proto](./admin/v1/admin_insights.proto) | `admin_insights_compat.go` |
| LLM | [llm/v1/](./llm/v1/) | 域 proto + 灰度 |

## 相关文档

- [LAYOUT.md](../LAYOUT.md)
- [scripts/README.md](../scripts/README.md)
