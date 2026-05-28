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
| Admin | [admin/v1/](./admin/v1/) | 待 PK-3 | — |
| LLM | [llm/v1/](./llm/v1/) | 待 PK-3 | — |

## 相关文档

- [docs/dev/kratos-pure-rollout.md](../docs/dev/kratos-pure-rollout.md)
