# API 契约（PK-1 纪律）

> **对外 HTTP 仍由 go-zero `moe.api` 生成路由（:8888）**；本目录 `api/<domain>/v1/*.proto` 为 **纯 Kratos / 域 SSOT**，与 `gowork/core-platform` 对齐。

## 规则（PK-1 起强制）

1. **新接口** → 只加 `api/<domain>/v1/*.proto`，**禁止**扩大 `api/defs/common.api` 巨石。
2. **HTTP 路径** 在 proto 顶部用注释写明，须与现有 `moe.api` 路径 **完全一致**（Flutter / moe-admin 不改端口）。
3. **实现** → `internal/biz/<domain>` + `internal/service/<domain>`；`moekratos` 注册试点 HTTP（:19032）。
4. **生产灰度（PK-2）** → `*gw` 可选转发到 `moe-kratos` HTTP，见 `config.yaml` 的 `moe.kratos_*_http_enabled`。

## 生成

```bash
cd backend
make gen-moe-proto    # api/**/v1/*.proto → *.pb.go
make gen-moe-conf     # internal/conf/moe/v1
```

## 域索引

| 域 | Proto | 试点 HTTP（:19032） | 生产灰度 |
|----|-------|---------------------|----------|
| Moe Admin | [moe/v1/moe.proto](./moe/v1/moe.proto) | `moekratospilot` AdminCompat | `kratos_admin_http_enabled` |
| VIP 只读 | [vip/v1/vip_read.proto](./vip/v1/vip_read.proto) | `RegisterVipCompat` | `kratos_vip_http_enabled` |
| Admin Insights | [admin/v1/admin_insights.proto](./admin/v1/admin_insights.proto) | PK-3 ✅ | `kratos_admin_insights_http_enabled` |
| LLM | [llm/v1/](./llm/v1/) | 待 PK-3 | — |

## 完整纯 Kratos（PK-6）

**HTTP 全量（已落地）**：`make gen-moekratospilot-get` → `routes_native_gen.go`（域原生）+ `routes_bridge_gen.go`（遗留 bridge）。

```bash
make gen-api                 # routes 变更后
make gen-moekratospilot-get  # 同步 GET 到 Kratos
make verify-kratos-rollout-pk6
```

POST/写路径与域 proto 见 [kratos-pure-complete-migration.md](../docs/dev/kratos-pure-complete-migration.md)。

## 相关文档

- [docs/dev/kratos-pure-rollout.md](../docs/dev/kratos-pure-rollout.md)
- [docs/dev/kratos-pure-complete-migration.md](../docs/dev/kratos-pure-complete-migration.md)
