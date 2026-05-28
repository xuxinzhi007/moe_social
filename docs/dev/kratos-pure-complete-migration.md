# 纯 Kratos 完整迁移方案（PK-5 → PK-9）

> **状态**：已立项 · **前置**：PK-0～4 ✅ · F ~100% · B（试点）100%  
> **当前 G**：~93%（PK-6 GET 批量后；`curl …/migration`）· **HTTP 路由覆盖 ~50%**（133/267 GET）  
> **目标 G**：**100%** — `make moe-social` 仅 Kratos `transport/http` + `transport/grpc`，无 go-zero `rest`/`zrpc` 生产路径  
> **阶段手册**：[kratos-pure-rollout.md](./kratos-pure-rollout.md) · **勾选**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 终态定义（什么叫「完整迁移」）

| 维度 | Hybrid 现在 | 纯 Kratos 终态 |
|------|-------------|----------------|
| 对外 HTTP | go-zero `rest` :8888（或 PK-4 前置 + :18888 回退） | **Kratos HTTP** :8888，**无** go-zero 回退 |
| 对内 gRPC | go-zero `zrpc` :8080 | **Kratos gRPC** :8080（域 service 注册） |
| 契约 SSOT | `moe.api` + goctl handler/logic | **`api/<domain>/v1/*.proto`** + `make gen-moe-proto` |
| 业务 | `internal/biz` + `*gw` | **保留 `biz`**；GW 变薄或并入 `internal/service` |
| 进程 | `moe-social` 单进程 | **仍单进程**（与 co 一致，非按域拆微服务） |
| 客户端 | Flutter / moe-admin :8888 路径不变 | **不变** |

**明确不做（除非另开项目）**：

- 拆成多仓库 / 多部署单元 per 域  
- 改 Flutter 基址或大规模改路径  
- 单 PR 同时「换传输 + 删 goctl + 改 proto 包名 `pb/super`」

---

## 2. 为什么现在可以开完整迁移

| 已完成 | 意义 |
|--------|------|
| F ~100% | HTTP logic 经 `*gw` → `biz`，迁传输 **不重写业务** |
| FS-9 | 契约分片 `defs/` + `moe.api`/`moe.proto` 入口 |
| PK-3 | `moekratospilot.RegisterAll` 多域读路径已在 Kratos HTTP 验证 |
| PK-4 | 同进程 Kratos 前置 + go-zero 内网回退 **已可实现** |
| `moekratos` + Wire | 装配模板与 co 同构，扩域即可 |

**主要剩余工作**：把 **~95% 仍未在 RegisterAll 的 HTTP 路由** 和 **全部 zrpc Super** 按域搬到 Kratos 生成/注册链，再 **关掉 go-zero 回退**。

---

## 3. 进度口径（双指标）

### percent — 完整纯 Kratos 实现度（主指标，`/migration`）

```text
percent = 40%×http_native_handler
        + 30%×grpc_service_native
        + 20%×http_transport_kratos
        + 10%×grpc_transport_kratos
```

- **http_native_handler**：`moekratospilot` 原生 handler / 267（非 bridge）
- **grpc_service_native**：`moegrpc` / (Super+zrpc logic) 占比
- **grpc_transport_kratos**：须 `kratos/transport/grpc` 替代 zrpc（当前 Super 仍为 0 分）
- **当前约 23%**（传输已纯、实现层仍 bridge）

### rollout_percent — PK 传输铺轨（可达 100%）

```text
rollout = 20%×biz + 20%×contract + 30%×route_on_kratos + 30%×transport_rollout
```

`kratos_pure_enabled=true` 时 **rollout_percent=100**；**不等于**完整纯 Kratos。

| 里程碑 | rollout | percent（约） | 验收 |
|--------|---------|---------------|------|
| PK-9 铺轨 | 100 | rollout 100 | `make verify-kratos-rollout-100` |
| PK-10b HTTP 全原生 | 100 | **≥90** | `make verify-kratos-pure-90` |
| 终态 100% | 100 | **100** | Super 迁 kratos/transport/grpc |

---

## 4. 阶段拆分（执行顺序）

### PK-5 — 完整迁移启动（1～2 周）

**目标**：生产链路默认走 Kratos HTTP 前置；固化回归门禁。

| 动作 | 说明 |
|------|------|
| 预发/本地 | `kratos_http_front_enabled: true` |
| 回归 | **每个 PR** `make verify-kratos-rollout-regression` |
| 发版前 | `make verify-kratos-rollout-regression-full` |
| 监控 | moe-admin 核心页 + `curl` 已迁移路由 + 一条未迁移路由（应 18888 回退） |
| 文档 | 本文件 + rollout §PK-5 勾选 |

**回滚**：`kratos_http_front_enabled: false` → 立即回到纯 go-zero HTTP。

---

### PK-6 — HTTP 全量按域（核心，约 8～12 周）

**原则**：一域一 PR；路径与 `moe.api` **字节级一致**；实现只调已有 `biz` / `service`。

**推荐顺序**（流量小、依赖少 → 大）：

| 批次 | 域 | defs 来源 | proto / 试点 | 回归 |
|------|-----|-----------|--------------|------|
| 6a | Platform / Landing | `platform.api` `landing.api` | 新建/扩 proto | `verify-sprint-s4-misc` |
| 6b | VIP 写 + 订单读 | `vip.api` | 扩 `vip/v1` | `verify-domain-vip` |
| 6c | Moe Admin 写 | `moe.api` | 扩 `moe/v1` | `verify-moe-complete` |
| 6d | Admin CRUD 批 | `admin.api` | 扩 `admin/v1` | `verify-sprint-f101-admin` 等 |
| 6e | User 登录/资料 | `user.api` | 新建 `user/v1` | `verify-domain-user` |
| 6f | 社交 | `social.api` | post/comment/community/gift proto | `verify-sprint-f90`…`f100d` |
| 6g | AI / LLM 写 | `ai_llm.api` | `ai/v1` `llm/v1` | `verify-sprint-f103-llm-inference` |
| 6h | Chat / Realtime | `realtime.api` | `chat/v1` | `verify-sprint-f107-chat-read` |

**每域 PR 模板**：

```text
1. api/<domain>/v1/*.proto（google.api.http 路径 = 现 moe.api）
2. make gen-moe-proto
3. internal/service/<domain> 薄层 → biz（复用 *gw 逻辑或内联调用 biz）
4. moekratospilot 或 internal/server/moekratoshttp 注册（生产走 PK-4 前置）
5. 从 go-zero 该域 handler 标 DEPRECATED / 路由不再命中（由 Kratos 先匹配）
6. make verify-kratos-rollout-regression + 域 verify-*
7. 更新 kratos-migration-status.md 域勾选
```

**PK-6 完成标准**：`RegisterAll`（或生成 Register）覆盖 **>95% HTTP 路由**；go-zero 内网仅兜底或关闭。

---

### PK-7 — gRPC 从 zrpc 迁到 Kratos（约 4～6 周）

**目标**：`:8080` 由 Kratos `transport/grpc` 提供；`super.Super` 按域拆 `Register*Server`。

| 动作 | 说明 |
|------|------|
| 模式 | 已有 `moegrpc` + `moe.proto`；按域复制 |
| 优先 | Admin / User / LLM RPC（RPC logic 仍厚者优先薄化） |
| in_process | API 同进程优先 **直调 service/biz**，避免 HTTP→gRPC 回环 |
| 验收 | `verify-sprint-fs10` + 域 RPC 测试 |

**注意**：HTTP 已 in_process 的域，迁 gRPC 主要为 **统一栈** 与 **淘汰 zrpc**，延迟收益有限。

---

### PK-8 — 退役 go-zero 生成链（约 2～4 周）

| 动作 | 说明 |
|------|------|
| `moesocial/run.go` | 删除 `wrapREST` / `apirun.Start` go-zero 路径 |
| `api/internal/handler` | 按域删除或仅留兼容壳 |
| `moe.api` | 空壳或删除；`make gen-api` 改为可选/废弃 |
| PK-4 回退 | 移除 `HandlePrefix` → :18888（无 legacy 即可） |

**独立 sprint（高风险）**：`pb/super` → `pb/moe` 包名（FS-9b），与 PK-8 **分 PR**。

---

### PK-9 — 100% 验收与默认纯 Kratos

```bash
cd backend
make verify-kratos-rollout-100    # 待实现：G=100 + 无 go-zero 生产 import
make verify-kratos-rollout-regression-full
make build-moe-social
# 手工：仅 make moe-social，无 moe-kratos 并行依赖
```

**配置默认**：

```yaml
moe:
  kratos_http_front_enabled: true   # 终态 true；PK-8 后可能删除开关
  # 无 kratos_internal_http_port（无 go-zero 回退）
```

---

## 5. 架构演进示意

```text
【现在 Hybrid】
Client → :8888 go-zero rest → *gw → biz
              ↘ SuperRpc → :8080 zrpc

【PK-4 可选】
Client → :8888 Kratos HTTP (试点路由) → biz
              ↘ 其它 → :18888 go-zero

【PK-6～7 目标】
Client → :8888 Kratos HTTP (全路由) → service → biz
              ↘ 少量 legacy → :8080 Kratos gRPC

【PK-8～9 终态】
Client → :8888 Kratos HTTP → service → biz
         （同进程）Kratos gRPC :8080 仅外部/工具调用
```

---

## 6. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 路由遗漏 | PK-4 回退保留至 PK-6 结束；每域 diff `moe.api` 路由表 |
| 行为回归 | 强制 `verify-kratos-rollout-regression`；发版前 full regression |
| proto 与 goctl 双写 | PK-6 内禁止改 `common.api` 巨石；只扩域 proto |
| `pb/super` 改名 | 独立 FS-9b sprint，不绑 PK-8 |
| 周期过长 | 6a～6h 并行 2 条线（Admin 线 + User/社交线） |

---

## 7. 团队分工建议

| 角色 | 负责 |
|------|------|
| 架构 | PK-5/7/8 开关与 `moesocial` 编排；Wire ProviderSet |
| 域 owner | PK-6 按批认领 proto + HTTP 注册 |
| QA | 每批 smoke 清单（moe-admin 页 + Flutter 主路径） |
| 全员 | PR 贴 §6 检查清单 + regression make 输出 |

---

## 8. 相关命令（SSOT）

```bash
cd backend

# 每 PR（轻量回归，必跑）
make verify-kratos-rollout-regression

# 发版 / 大批合并前（含 F 全量回归，耗时长）
make verify-kratos-rollout-regression-full

# 当前 PK 门禁
make verify-kratos-rollout-pk34
make verify-kratos-100

# 业务全量（F）
make verify-sprint-regression
```

---

## 9. 下一步（建议立即执行）

1. **本周**：预发打开 `kratos_http_front_enabled: true`，跑通 regression + moe-admin smoke。  
2. **下周 PR**：PK-6a Platform/Landing proto + Register（小域练手）。  
3. **里程碑**：6 周内 G≥95%；12 周内 PK-6 完成；再排 PK-7/8。

更新勾选见 [kratos-migration-status.md](./kratos-migration-status.md) §「PK 完整迁移」。
