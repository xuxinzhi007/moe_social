# 纯 Kratos 落地行动手册（PK）

> **更新：2026-05-27** · **前置已完成**：Hybrid F100% · FS-8/8b/9/10 · 试点 B（`make moe-kratos`）100%  
> **对标**：公司内 **`gowork/core-platform`**（纯 Kratos + 分域 proto + Wire）  
> **生产不变**：对外仍 **HTTP :8888**（`make moe-social`）；PK 阶段在 **:19031/:19032** 或灰度开关上验证

---

## 0. 三条曲线（别混）

| 曲线 | 含义 | 状态 | 验收 |
|------|------|------|------|
| **F** | 业务下沉 `biz` + `*gw` in_process | ✅ ~100% | `make verify-sprint-f112` |
| **FS** | 契约分片 + 退役 `super.api/proto` 文件名 | ✅ FS-9 | `make verify-sprint-fs9` |
| **PK** | **传输/生成链** 对齐 core-platform 纯 Kratos | 🔄 **本手册** | `make verify-kratos-rollout-pk0` → PK-n |

**PK 不等于立刻替换 `make moe-social`**。每阶段可停在 Hybrid，Flutter / moe-admin **路径与端口不变**。

---

## 1. 和 core-platform（co）的差异与性能预期

| 维度 | moe 现在（Hybrid 生产） | co（core-platform） | PK 目标 |
|------|-------------------------|---------------------|---------|
| HTTP | go-zero `rest` | `kratos/transport/http` | 按域替换 |
| gRPC | go-zero `zrpc` | `kratos/transport/grpc` | 按域替换 |
| 主路径延迟 | `*gw` → `biz`（无 :8080 回环） | `service` → `biz` | 已对齐；换框架 **非性能主因** |
| 契约 | `moe.api` + goctl | `api/<domain>/v1/*.proto` | 新能力只加域 proto |
| DI | `svc` + `moewiring` | Wire | 试点已 Wire（`moekratos`） |

详见 [moe-social-runtime.md](./moe-social-runtime.md)、[kratos-migration.md §8–9](./kratos-migration.md#8-与纯-kratos-差异一览)。

---

## 2. 仓库里纯 Kratos 已有什么（直接复用）

| 路径 | 作用 |
|------|------|
| `cmd/moe-kratos/` | 纯 Kratos 进程入口 |
| `internal/platform/moekratos/` | Wire 装配、`kratos.App` |
| `internal/server/moekratoshttp/` | Kratos HTTP 注册 |
| `internal/server/moegrpc/` | Kratos gRPC `MoeAdmin` |
| `api/moe/v1/moe.proto` | Moe Admin gRPC 契约 |
| `api/vip/v1/vip_read.proto` | VIP 套餐只读（试点 HTTP） |
| `api/moekratospilot/` | 与 go-zero 路径兼容的 HTTP 适配 |
| `internal/conf/moe/v1/` | `Bootstrap` conf.proto |

**不要新建第二套试点进程**；在 `moekratos` 上扩展域即可。

---

## 3. PK 阶段（执行顺序）

### PK-0 — 基线（每次开工先跑）

```bash
cd backend
make verify-kratos-rollout-70    # ≥70% 团队口径（PK-0～3）
make verify-kratos-rollout-pk0   # 文档 + 试点 + Hybrid 契约
make verify-kratos-100           # 试点 B 100% + Hybrid 回归
make verify-sprint-fs9           # moe.api / moe.proto / 无 super.yaml
```

**完成标准**：全部 exit 0；本地可 `make moe-social` 与 `make moe-kratos` 并行。

---

### PK-1 — 契约纪律（1～2 周，低风险）

**目标**：新接口 **只** 进域 proto，不再扩大 `api/defs/common.api` 巨石。

| 动作 | 说明 |
|------|------|
| 新 HTTP/RPC | 在 `api/<domain>/v1/*.proto` 定义；`google.api.http` 注解与 co 一致 |
| 生成 | `make gen-moe-proto`（或域 Makefile 目标） |
| 实现 | `internal/service/<domain>` + 复用已有 `internal/biz/<domain>` |
| 注册 | `moekratos` HTTP/gRPC 注册；**生产仍走 GW** 直到 PK-3 |

**首个推荐域（已有 stub）**：

1. **VIP 套餐只读** — 已有 `vip_read.proto` + `RegisterVipCompat`  
2. **Moe Admin 读** — 已有 `moe.proto` + `moeadmin` service  

**验收**：`make verify-kratos-100` + 手工 `curl` 见 §5。

---

### PK-2 — 灰度一条生产路径（1 周）

**目标**：`:8888` 上 **单条** Moe Admin 读接口经 `MoeGW` 转发到 `:19032`（已有开关）。

1. 终端 A：`make moe-kratos`（或 `-super-rpc 127.0.0.1:8080` 如需 legacy）  
2. 终端 B：`make moe-social`  
3. `backend/config/config.yaml`：

```yaml
moe:
  kratos_admin_http_enabled: true   # Moe: ListRuntimes, GetBrainPipeline
  kratos_vip_http_enabled: true     # VIP: ListPlans（GET /api/admin/vip/plans）
  kratos_admin_base_url: "http://127.0.0.1:19032"
```

4. 打 Moe / VIP 灰度读接口（见 [api/moe/v1/README.md](../../backend/api/moe/v1/README.md)）  
5. 日志应出现：`moe admin gateway route: kratos_http` 或 `vip gateway route: kratos_http`

**回滚**：`kratos_admin_http_enabled: false` → 立即回到 in_process。

**验收**：`make verify-kratos-100`；moe-admin 对应页无回归。

---

### PK-3 — 按域扩 Kratos HTTP（✅ 多域试点）

**已落地**（`api/moekratospilot/RegisterAll`）：

| 域 | 路由示例 | 文件 |
|----|----------|------|
| Moe Admin | `/kratos/v1/moe/*` | `admin_compat.go` |
| VIP 只读 | `GET /api/admin/vip/plans` | `vip_compat.go` |
| Admin Insights | `/api/admin/insights/*` | `admin_insights_compat.go` |
| Admin 只读 | `/api/admin/dashboard` 等 | `admin_readonly_compat.go` |
| LLM 读 | `/api/llm/models` 等 | `llm_read_compat.go` |

**验收**：`make verify-kratos-rollout-pk3` · `make moe-kratos` curl §5

---

### PK-6 — HTTP 全量（✅ GET+POST+PUT+DELETE）

**做法**：`make gen-moekratospilot-get` 生成 `routes_handlers_gen.go`（**267 条**，与 `routes.go` 一致），Kratos 复用 go-zero `handler`。

```bash
make gen-api
make gen-moekratospilot-get
make verify-kratos-rollout-pk6
```

### PK-7 — zrpc 纳入 Kratos 生命周期（✅）

`internal/platform/moesocial/kratos_grpc.go` · 配置 `moe.kratos_grpc_managed: true` 时 `kratos.App` 同时管理 HTTP + gRPC（:8080）。

```bash
make verify-kratos-rollout-pk7
```

---

### PK-3（历史模板）— 按域扩 Kratos HTTP（按月，与 co 对齐）

每域一个 PR，模板：

```text
1. api/<domain>/v1/*.proto（HTTP 注解路径与 super.api 现路径一致）
2. make gen-moe-proto && Wire 注册 moekratoshttp
3. service 薄层 → 已有 biz
4. moekratos 上 curl 验收
5. 可选：该域 GW 增加 kratos_http 分支（仿 MoeGW）
6. make verify-sprint-regression + 域 verify-* 
```

**建议顺序**（依赖少 → 多）：

| 顺序 | 域 | 已有 stub | 备注 |
|------|-----|-----------|------|
| 1 | VIP 套餐 | `api/vip/v1/vip_read.proto` | 只读、已试点 |
| 2 | Moe Admin | `api/moe/v1/moe.proto` | 灰度已支持 |
| 3 | Admin insights | `api/admin/v1/admin_insights.proto` | 管理台 |
| 4 | LLM catalog | `api/llm/v1/llm_chat.proto` | 读多写少 |
| 5 | User / 社交 | 新建 proto | 工作量大，放后 |

**禁止**：单 PR 同时改传输 + 删 goctl + 改 Flutter 路径。

---

### PK-4 — Kratos HTTP 前置层（✅ 可选开关）

**目标**：对外仍 **:8888**，已迁移路由走 **Kratos `transport/http`**；其余 **反向代理** 到内网 go-zero。

| 组件 | 说明 |
|------|------|
| `internal/platform/moesocial/kratos_front.go` | `RegisterAll` + `HandlePrefix` 回退 |
| `api/runserver.StartWithResult` | `InternalHTTPPort`（默认 **18888**） |
| 配置 | `moe.kratos_http_front_enabled` · `moe.kratos_internal_http_port` |

**启用**（`backend/config/config.yaml`）：

```yaml
moe:
  kratos_http_front_enabled: true
  kratos_internal_http_port: 18888
```

**默认**：`false` — 仍 `wrapREST(go-zero)`，与历史 Hybrid 一致。

**验收**：`make verify-kratos-rollout-pk4` · `make verify-kratos-rollout-85`

**风险**：生产启用前需对灰度读接口做 smoke；zrpc 仍 :8080，未在本阶段替换。

---

### PK-5～9 — 完整纯 Kratos 迁移（已立项）

**SSOT**：[kratos-pure-complete-migration.md](./kratos-pure-complete-migration.md)

| 阶段 | 目标 | 约 G |
|------|------|------|
| **PK-5** | 预发默认 PK-4 + 回归门禁固化 | ~93% |
| **PK-6** | HTTP 全量按域（`defs/*.api` → 域 proto + Register） | ~96% |
| **PK-7** | zrpc → Kratos gRPC | ~99% |
| **PK-8** | 退役 goctl handler / `wrapREST` | — |
| **PK-9** | 传输铺轨 rollout=100%；完整纯 Kratos percent 见 /migration | rollout ✅ |

**每个 PR 必跑**：

```bash
make verify-kratos-rollout-regression        # 轻量
make verify-kratos-rollout-regression-full   # 发版前
```

**PK-5 快速项**（原「远期」拆细）：

- 预发 `kratos_http_front_enabled: true`  
- 扩 `RegisterAll` 高流量读路由  
- **不** 在本阶段删 `moe.api` / 改 `pb/super` 包名  

---

### PK-5（历史简述）— 退役 goctl

并入 PK-8；`pb/super` 改名见 FS-9b 独立 sprint。

---

## 4. 日常命令速查

```bash
cd backend

# 生产 / 日常开发（Hybrid）
make moe-social

# 纯 Kratos 试点（:dev only）
make moe-kratos
make moe-kratos SUPER_RPC_ARGS="-super-rpc 127.0.0.1:8080"   # 如需连 legacy Super

# 生成
make gen-moe-proto      # 域 proto
make gen-moe-conf       # moe.conf.v1
cd internal/platform/moekratos && wire   # 改 Wire 后

# 验收
make verify-kratos-rollout-pk0
make verify-kratos-rollout-pk34   # PK-3 + PK-4（≥85%）
make verify-kratos-100
make verify-sprint-fs9
```

配置默认：`api/etc/moe.yaml`、`rpc/etc/moe.yaml`（**不是** `super.yaml`）。

---

## 5. PK-1 手工 smoke（moe-kratos 起来后）

```bash
# 健康 / 试点进度
curl -s http://127.0.0.1:19032/health
curl -s http://127.0.0.1:19032/migration

# Moe Admin（路径以 moekratospilot 注册为准）
curl -s http://127.0.0.1:19032/kratos/v1/moe/runtimes

# VIP 只读（需库里有数据）
curl -s http://127.0.0.1:19032/api/admin/vip/plans
```

---

## 6. PR 检查清单（每个 PK PR 粘贴）

- [ ] 未改 Flutter / moe-admin 基址（仍 :8888）除非明确灰度文档  
- [ ] 新契约在 `api/<domain>/v1/`，未扩 `common.api` 巨石（PK-1+）  
- [ ] `internal/biz` 承载业务；service 仅适配  
- [ ] `make verify-kratos-rollout-regression` 通过（PK PR 必跑）  
- [ ] 发版前 `make verify-kratos-rollout-regression-full`（含 F 全量）  
- [ ] 相关 `make verify-sprint-*` / 域 `verify-domain-*` 通过  
- [ ] 更新本文件或 [kratos-migration-status.md](./kratos-migration-status.md) 勾选 PK-n  

---

## 7. 相关文档

| 文档 | 用途 |
|------|------|
| [kratos-migration.md](./kratos-migration.md) | Hybrid SSOT、决策 §9 |
| [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) | 试点 B 历史（Phase 0～6 ✅） |
| [kratos-migration-status.md](./kratos-migration-status.md) | 总进度勾选 |
| [moe-social-runtime.md](./moe-social-runtime.md) | 单进程 Hybrid 说明 |
| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | 与 PK 并行的 goctl 卫生 |

---

## 8. 当前 PK 进度（人工维护）

| 阶段 | 状态 | 备注 |
|------|------|------|
| PK-0 基线 | ✅ | `verify-kratos-rollout-pk0` |
| PK-1 契约纪律 | ✅ | `api/README.md` + 域 proto；`make verify-kratos-rollout-pk1` |
| PK-2 灰度 | ✅ | `kratos_admin_http_enabled` + `kratos_vip_http_enabled`；`make verify-kratos-rollout-pk2` |
| PK-3 扩域 | ✅ | Insights + Admin RO + LLM read · `make verify-kratos-rollout-pk3` |
| PK-4 HTTP 前置 | ✅ 可选 | `kratos_http_front_enabled` · `make verify-kratos-rollout-pk4` |
| PK-5～9 完整迁移 | 🔄 已立项 | [kratos-pure-complete-migration.md](./kratos-pure-complete-migration.md) |
