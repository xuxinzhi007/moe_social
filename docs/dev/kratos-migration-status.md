# Kratos 迁移 — 状态板（Current / Next）

> **最后更新：2026-05-27**  
> **读这个**：本文 = **当前状态 + 下一步** 快照；细节见 [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) · 架构见 [kratos-migration.md](./kratos-migration.md)

---

## 当前状态（Current）

### 阶段定位

| 阶段 | 状态 | 说明 |
|------|------|------|
| **P0 · 传输 / PK** | ✅ 完成 | 单进程 Kratos · HTTP `:8888` · gRPC `:8080` · `/migration` ≈ 100% |
| **P1 · HTTP 挂 Kratos** | ✅ 完成 | `routes_native_gen = 0` · compat **263** 条 · bridge **2** |
| **P2 · 实现层直挂 App** | 🔄 **进行中（~21%）** | **56/263** 条 compat 直接调 `internal/service` |
| **P3 · logic 退役** | ⏳ 未开始 | 删 `api/internal/logic/<group>` 需在 P2 域 Done 后 |

### P1 已完成清单（2026-05-27）

- [x] 删除聚合 compat：`user_logic_compat` · `wave2_logic_compat` · `platform_logic_compat` · `admin_logic_compat`
- [x] 按域注册：`register_all.go` → 20+ 个 `Register*Compat`
- [x] 直挂 App 域：checkin · achievement · behavior · gift · comment · **post** · **community** + pilot 读路径
- [x] 薄转拆分：`user_*` · `ai` · `chat` · `wave2_misc` · `admin_service` + `admin_legacy` · `platform`
- [x] 共享：`compat_invoke.go`（`invokeLogicJSON`）
- [x] 域 proto 占位：**15** 个 `api/*/v1/*.proto`（含 `user` · `community` · `post` · `gift` · `comment`）
- [x] 文档 / 规则同步；`make check` 通过
- [x] 大任务协作规则：[parallel-agent-workflow.md](../guidelines/parallel-agent-workflow.md) · `.cursor/rules/parallel-agent-workflow.mdc`

### P2 实现层快照（263 条 compat）

| 分档 | 条数 | 含义 |
|------|------|------|
| **A · 直挂 App** | **56** | `*_compat.go` → `internal/service/*` |
| **B · invokeLogicJSON** | **~107** | compat → `api/internal/logic` → `*GW` (in_process) |
| **C · wrapNativeHTTP** | **~100** | compat → goctl `handler` → logic（OAuth/WS/流式等） |

完整文件级清单：[kratos-legacy-api-migration.md §2.1](./kratos-legacy-api-migration.md#21-apimoehttp-compat-清单263-路由)。

### 业务底座（已就绪，P2 可直接用）

- `internal/biz/*`：17 域 · logic **无** `SuperRpcClient`
- `internal/service/*`：14 个 `AppService`（含 `user` · `admin` · `community` · `llm` · `ai` · `chat`）
- `*GW`：默认 **in_process**（logic 壳去掉后行为不变）

---

## 下一步（Next）

### 目标状态（P2 完成时）

| 指标 | 当前 | 目标 |
|------|------|------|
| 直挂 App 路由数 | **56** | **263**（能直挂的尽量 A 档） |
| 实现层进度 | **~21%** | **~100%**（WS/OAuth/流式可保留 C 档） |
| `admin_service_compat` | logic 薄转 | **`AdminApp` 直调** |
| `user_*` | handler 薄转 | **`UserApp` / `LLMApp` 直调** |
| `ai` / 私信 | logic 薄转 | **`AIApp` / `ChatApp` 直调** |
| `platform` LLM 写 | 混合 | **`LLMApp` 直调**（chat 复杂逻辑可最后） |

**不改变的**：对外 URL、JSON 字段、Flutter / moe-admin 契约；`routes_native_gen` 保持 **0**。

### 推荐波次（可并行）

> 执行方式：[parallel-agent-workflow.md](../guidelines/parallel-agent-workflow.md) — **一域一分支 / worktree**，`register_all.go` 由合并方单点改。

| 波次 | 子任务 | 路由数 | 主要改动 | 验收 |
|------|--------|--------|----------|------|
| **N1** | `admin_service_compat` → `AdminApp` | 55 | 去掉 `adminlogic` 壳；types 转换进 compat 或 `admin_convert.go` | `make check` + Admin 后台抽测 |
| **N2a** | `user_compat` → `UserApp` | 49 | 鉴权/资料/社交/VIP 子路径；OAuth 可暂留 C 档 | 登录/资料 API |
| **N2b** | `user_memory_compat` → `LLMApp` | 8 | 记忆 CRUD/搜索 | 记忆相关 API |
| **N3a** | `ai_compat` → `AIApp` | 14 | agents/providers/lorebooks | AI 配置页 |
| **N3b** | `chat_compat` 私信 → `ChatApp` | 3 | PM 三条；**WS 保持** wrapNativeHTTP | 私信收发 |
| **N4** | `platform_compat` LLM 写 | ~6 | create-agent/chat/delete/download；raw/chat 流式可后置 | LLM 对话 |
| **N5** | `wave2_misc_compat` | 27 | 按子域拆（avatar/emoji/…）；可新建 service 或暂留 B 档 | 分域 PR |
| **N6** | `admin_legacy_compat` | 28 | Moe brain/运行时；部分长期保留 C 档 | Admin Moe 页 |

**合并顺序建议**：N1 → N2a/N2b（可并行）→ N3 → N4；N5/N6 与 N4 可并行但优先级略低。

### 近期 PR / 会话检查表

- [ ] 子任务边界写清（改哪些 `*_compat.go`、禁止动哪些）
- [ ] `cd backend && make check`
- [ ] 未引入 `api/defs` 新路由
- [ ] 合并后更新 **本文** + [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) §0 数字
- [ ] 共享文件仅合并一次：`register_all.go` · `route_stats.go` · `skipExactPaths`

### P3（P2 之后）

- [ ] 按域删除已无引用的 `api/internal/logic/<group>`
- [ ] 补全各域 proto RPC（由 Ping 占位升级为真实方法列表）
- [ ] 评估 `handler` 层是否可收口（OAuth/WS 可能长期保留）

---

## 总览表（与 `/migration` 区分）

| 项 | 状态 |
|----|------|
| 生产入口 | ✅ `make moe-social` |
| Kratos HTTP | ✅ `native_gen=0` · `bridge=2` · compat **263** |
| 实现层直挂 App | 🔄 **56/263（~21%）** |
| 新接口纪律 | 🔄 走 [new-api-kratos.md](./new-api-kratos.md) |

## 已废弃（勿引用）

`make moe-kratos` · `make verify-*` · `user_logic_compat.go` · `wave2_logic_compat.go` · `platform_logic_compat.go` · `admin_logic_compat.go`

## 自检

```bash
cd backend && make check && make moe-social
curl -s http://127.0.0.1:8888/migration
curl -s http://127.0.0.1:8888/health
```
