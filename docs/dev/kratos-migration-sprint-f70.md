# 全站迁移冲刺：+10% F（小步快跑 + 逐步验收）

> **状态：历史文档**（起点 F≈60% → 目标 F≈70%）  
> **当前进度**：F ≈ **98%**（F109 完成）→ 见 [kratos-migration-status.md](./kratos-migration-status.md) · [kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md)

> **起点**：F ≈ **60%**（Sprint F70 完成）  
> **目标**：F ≈ **70%**  
> **原则**：每次只迁 **logic 少、无跨域事务** 的子域；**每步独立 `make verify-sprint-*`**

---

## 进度公式（不变）

```text
F = Σ (域权重 × 域内进度)
域内进度：0 → 20 → 60 → 100（见 kratos-full-site-migration-plan.md §1.1）
```

本冲刺四步预计 **+10%**：

| 步 | 内容 | ΔF（约） | 验收 |
|----|------|----------|------|
| **S1** | Landing HTTP 全 in_process（补 API 直连 biz） | +0.5% | `make verify-sprint-s1-landing` |
| **S2** | User VIP 订单 `GetVipOrders` → biz/user | +1% | `make verify-sprint-s2-user-vip` |
| **S3** | Admin 只读 3 接口（growth / schema / runtime） | +4% | `make verify-sprint-s3-admin-ro` |
| **S4** | Doc + ops 配置只读（swagger / public config 已迁则跳过） | +1% | `make verify-sprint-s4-misc` |
| **S5** | Notification 广播 3 接口 → biz/notify | +2.5% | `make verify-sprint-s5-notify` |
| **回归** | 全站 Hybrid | — | `make verify-sprint-f70` |

**累计验收**：`make verify-sprint-f70` = S1～S5 + `verify-full-site-50`。Windows：`powershell -File scripts/verify-sprint-f70.ps1`

---

## S1 — Landing 域 HTTP 100%

**问题**：RPC 已用 `landingbiz`，API 仍 `SuperRpcClient` 绕一圈。

**改法**：

- `internal/service/landing` + `landinggw`
- `moe.landing_api_in_process: true`
- `submitlandingfeedbacklogic` / `listlandingfeedbacklogic` → gateway

**验证**：grep + `go test` + `go build ./cmd/moe-social`

---

## S2 — User VIP 订单

**范围**：`GET /api/user/.../vip/orders`（`GetVipOrders`）

**改法**：

- `internal/biz/user/vip_orders.go`
- `userapp.GetVipOrders` + `usergw.GetVipOrders`
- RPC `getviporderslogic` 转调 biz

**验证**：`verify-sprint-s2-user-vip`

---

## S3 — Admin 只读（FS-4a 首批）

**范围**（3 条，无写库）：

- `AdminGetGrowthStats`
- `AdminGetSchemaCatalog`
- `AdminGetRuntimeConfig`

**改法**：

- `internal/biz/admin/{growth,schema,runtime}.go`
- `admingw` + `moe.admin_readonly_api_in_process`

**验证**：`verify-sprint-s3-admin-ro`

---

## S4 / S5 — 已完成

- **S4**：`behaviorgw` + appcfg/doc 已 in_process → `make verify-sprint-s4-misc`
- **S5**：`biz/notify` + `admingw` broadcast/send → `make verify-sprint-s5-notify`

完成 S5 后 F ≈ **70%**；后续见 [kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md)。

---

## 日常命令

```bash
cd backend
make verify-sprint-s1-landing    # 单步
make verify-sprint-f70             # 本冲刺批次回归
make moe-social                  # 本地联调
```
