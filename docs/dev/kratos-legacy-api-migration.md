# 存量 HTTP 接口迁移评估

> **状态快照更新：2026-05-27**  
> **状态板（勾选 / 汇报用）**：[kratos-migration-status.md](./kratos-migration-status.md)  
> SSOT 架构：[kratos-migration.md](./kratos-migration.md) · 新接口：[new-api-kratos.md](./new-api-kratos.md) · 并行协作：[parallel-agent-workflow.md](../guidelines/parallel-agent-workflow.md)  
> §0 与状态板数字不一致时，**以 `route_stats.go` + `make check` 为准**，并同步两处文档。

---

## 0. 状态快照（Now → Next）

### 0.1 当前状态（Latest）

**阶段名：传输完成 · 实现层收口（二期）**

| 维度 | 状态 | 说明 |
|------|------|------|
| **传输 / 路由注册** | ✅ 完成 | 268 goctl 路由均在 Kratos；`native_gen=0`；`bridge=2` |
| **compat 文件结构** | ✅ 完成 | 按域拆分 20+ 个 `*_compat.go`；已删 4 个聚合文件（见 §2.1） |
| **实现层直挂 App** | 🔄 **21%** | **56 / 263** 条 compat 直接调 `internal/service` |
| **invokeLogicJSON 薄转** | 🔄 进行中 | **~107** 条（ai、wave2_misc、admin CRUD、platform 部分） |
| **wrapNativeHTTP 薄转** | 🔄 进行中 | **~100** 条（user、记忆、WS、admin legacy、voice/moe） |
| **域 proto** | 🔄 部分 | **15** 个 `api/*/v1/*.proto`；多数为 Ping/占位，RPC 随域补全 |
| **biz + GW** | ✅ 完成 | `in_process`；logic 无 `SuperRpcClient` |
| **工程验收** | ✅ | `make check` 通过（moehttp + kratosprogress） |
| **协作方式** | ✅ 已落档 | `.cursor/rules/parallel-agent-workflow.mdc` + Playbook |

**本阶段已交付（2026-05-27 批次）**

- [x] `routes_native_gen` 从 247 → **0**
- [x] 删除 `user_logic_compat` / `wave2_logic_compat` / `platform_logic_compat` / `admin_logic_compat`
- [x] 新增并按域注册：`user_compat`、`user_memory_compat`、`community_compat`、`ai_compat`、`chat_compat`、`wave2_misc_compat`、`platform_compat`、`admin_service_compat`、`admin_legacy_compat`
- [x] 直挂 App：post(9)、gift(6)、comment(2)、community(11) 及波次 1 小域
- [x] 共享 `compat_invoke.go`；`register_all.go` 注册顺序稳定
- [x] 文档 / 规则 / `AGENTS.md` 与代码结构对齐

**代码锚点（改前先对表）**

```text
backend/api/moehttp/register_all.go   # 注册入口
backend/api/moehttp/route_stats.go      # PilotNativeCompatRoutes = 263
backend/api/moehttp/routes_native_gen.go # nativeDomainRouteCount = 0
```

---

### 0.2 下一步状态（Next）

**阶段名：实现层直挂 `internal/service`（按域并行）**

**目标（Done 时）**

| 指标 | 当前 | 下一步目标 |
|------|------|------------|
| 分档 A（直挂 App） | 56 / 263 | **263 / 263**（WS/流式允许保留 handler 包装） |
| `admin_service_compat` | logic 壳 | **直调 `AdminApp`** |
| `user_*` | handler 壳 | **`UserApp` + `LLMApp`（记忆）** |
| `ai_compat` / 私信 | logic 壳 | **`AIApp` / `ChatApp`** |
| `platform_compat` | 混合 | **`LLMApp` 覆盖写路径**；voice/moe 可暂留 handler |
| 活跃 `api/internal/logic` | 仍大量引用 | 按域删除无引用 logic（**最后**动 defs） |

**推荐并行子任务（4 轨，各 1 PR + 可选 worktree）**

| 轨道 | 范围 | 路由约计 | 分支示例 | 禁止改 |
|------|------|----------|----------|--------|
| **A** | `admin_service_compat.go` → `AdminApp` | 55 | `feat/admin-app-compat` | `user_*`、`platform_*` |
| **B** | `user_compat` + `user_memory_compat` | 57 | `feat/user-app-compat` | `admin_service_*` |
| **C** | `ai_compat` + `chat_compat`（私信直挂；WS 可不动） | 23 | `feat/ai-chat-app-compat` | admin、user |
| **D** | `platform_compat`（LLM 写优先） | 17 | `feat/platform-llm-compat` | admin、user |

**父会话/合并人唯一修改**：`register_all.go`、`route_stats.go`（若路由常量变化）、迁移文档 §0 快照。

**单轨验收（每 PR）**

```bash
cd backend && make check
# 手测该域 1～2 条关键 API
```

**阶段顺序建议**

1. **A（admin CRUD）** — 收益最大、面.admin 集中  
2. **B（user）** — 体量大，可按子域再拆（oauth / vip / 社交）  
3. **C（ai + chat PM）** — 与 B 弱依赖，可与 A 并行  
4. **D（platform LLM）** — `ChatLogic` 重，可放在 C 之后  
5. **收尾**：`wave2_misc_compat`（27）、`admin_legacy_compat`（28）按需直挂或长期保留 handler  
6. **全站**：删无引用 logic · 补全域 proto RPC · 更新 §0 快照为「实现层 100%」

---

### 0.3 阶段对照（一眼看懂）

```text
[已完成] PK / 传输层     Kratos :8888 全路由 + native_gen=0
[已完成] compat 拆分    263 条分文件注册 + make check
[进行中] 实现层直挂      56 → 263（本文件 §0.2）
[未开始] logic 物理删除  按域确认无引用后删
[保持]   bridge=2        swagger
```

---

## 结论（汇总表）

| 项 | 状态 |
|----|------|
| 传输层 Kratos :8888 | ✅ 268 条 goctl 路由均在 Kratos 注册 |
| `routes_native_gen` | ✅ **0**（无 goctl handler 直挂 gen） |
| `routes_bridge_gen` | **2**（swagger 文档） |
| `api/moehttp/*_compat.go` | ✅ **263** 条路由（`PilotNativeCompatRoutes`） |
| 实现层直挂 `internal/service` | 🔄 **~56** 条已直挂 App；其余经 logic / handler 薄转 |

生产已稳定；后续工作是 **HTTP 适配层** 从 logic/handler 收口到 `internal/service`，不改变对外路径与 JSON。

---

## 1. 两套「进度」不要混

| 口径 | 典型值 | 含义 |
|------|--------|------|
| `GET /migration` → `percent` | **100** | PK 权重：Kratos 传输 + biz/GW + 路由挂 Kratos |
| `http_native_handler_pct` | **100** | 凡在 Kratos 注册的 compat 均计为「native HTTP」 |
| **实现层直挂 App** | **~21%**（56/263） | `*_compat.go` 内直接调 `*App`，不经 `api/internal/logic` |

代码口径：`backend/api/moehttp/route_stats.go`（`PilotNativeCompatRoutes`、`nativeDomainRouteCount`、`bridgeRouteCount`）。

---

## 2. 路由构成（268 条 goctl）

| 类型 | 数量 | 说明 |
|------|------|------|
| `routes_native_gen` | **0** | `RegisterNativeDomainHTTPHandlers` 为空操作 |
| `*_compat` | **263** | 见下表 · `register_all.go` 注册 |
| `routes_bridge_gen` | **2** | swagger |

### 2.1 `api/moehttp` compat 清单（263 路由）

注册顺序见 `api/moehttp/register_all.go`。

| 文件 | 路由数 | 实现方式 | 目标 App / 说明 |
|------|--------|----------|-----------------|
| `admin_compat.go` | 2 | 直挂 | `internal/service/moe`（Moe Admin 读） |
| `admin_insights_compat.go` | 5 | 直挂 | `AdminApp` |
| `admin_readonly_compat.go` | 3 | 直挂 | `AdminApp` |
| `vip_compat.go` | 1 | 直挂 | DB 读 VIP plans |
| `llm_read_compat.go` | 2 | 直挂 | `LLMApp`（models / catalog） |
| `landing_compat.go` | 3 | 直挂 | `LandingApp` |
| `checkin_compat.go` | 7 | 直挂 | `CheckinApp` · `api/checkin/v1/` |
| `achievement_compat.go` | 4 | 直挂 | `AchievementApp` |
| `behavior_compat.go` | 1 | 直挂 | `BehaviorApp` |
| `gift_compat.go` | 6 | 直挂 | `GiftApp` · `api/gift/v1/` |
| `comment_compat.go` | 2 | 直挂 | `CommentApp` · `api/comment/v1/` |
| `post_compat.go` | 9 | 直挂 | `PostApp` + `CommentApp` · `api/post/v1/` |
| `community_compat.go` | 11 | 直挂 | `CommunityApp` · `api/community/v1/` |
| `user_compat.go` | 49 | `wrapNativeHTTP` | goctl `handler/user` → logic → `UserGW` |
| `user_memory_compat.go` | 8 | `wrapNativeHTTP` | 记忆子路径 → `LLMGW` / logic |
| `ai_compat.go` | 14 | `invokeLogicJSON` | `ailogic` → `AIGW` |
| `chat_compat.go` | 9 | 混合 | 私信 `invokeLogicJSON`；WS/在线 `wrapNativeHTTP` |
| `wave2_misc_compat.go` | 27 | `invokeLogicJSON` | avatar/emoji/image/notification/vip 公开/admin 登录等 |
| `admin_service_compat.go` | 55 | `invokeLogicJSON` | `adminlogic` → `AdminGW`（**待** 内联 `AdminApp`） |
| `admin_legacy_compat.go` | 28 | `wrapNativeHTTP` | Moe brain/flow、运行时、媒体等 |
| `platform_compat.go` | 17 | 混合 | LLM chat/agent `invokeLogicJSON`；config/raw/voice/moe `wrapNativeHTTP` |

共享辅助：`compat_invoke.go`（`invokeLogicJSON` / `invokeLogicEmpty`）。

**已删除（勿再引用）**：`user_logic_compat.go`、`wave2_logic_compat.go`、`platform_logic_compat.go`、`admin_logic_compat.go`（admin 已拆为 `admin_service_compat` + `admin_legacy_compat`）。

### 2.2 实现层分档（263 条）

| 分档 | 约计 | 代表 |
|------|------|------|
| **A · 直挂 `internal/service`** | **56** | post、gift、comment、checkin、achievement、behavior、community、landing、llm 读、admin insights/readonly、moe admin 读、vip 读 |
| **B · `invokeLogicJSON`** | **~107** | ai、wave2_misc、admin CRUD、platform 部分 LLM |
| **C · `wrapNativeHTTP`** | **~100** | user、user 记忆、chat WS、admin legacy、platform voice/moe |

---

## 3. 域 proto SSOT（`make gen-moe-proto`）

当前 **15** 个域 proto（Ping/占位 + 业务 RPC 逐步补全）：

`achievement` · `admin` · `admin_insights` · `ai` · `behavior` · `chat` · `checkin` · `comment` · `community` · `gift` · `llm` · `moe` · `post` · `user` · `vip`

新迁域请同步：`*_compat.go` + `api/<domain>/v1/*.proto` + `internal/service/<domain>/`。

---

## 4. 业务层（F 曲线）— 已完成

- `internal/biz/*`：**17** 个域包，逻辑 SSOT
- `api/internal/*gw`：均为 **`in_process`**（进程内调 biz，无 :8080 回环）
- `api/internal/logic`：**零** `SuperRpcClient`
- `internal/service/*`：**14** 个 `AppService`（`user` / `community` / `post` / `admin` / `llm` / `ai` / `chat` 等；无独立 `notify` / `appcfg` service）

---

## 5. 单域迁移步骤（模板）

以 **checkin** 为例（已完成，可作对照）：

1. 新增/补全 `api/checkin/v1/checkin.proto`（路径与 `api/defs` 一致）
2. `make gen-moe-proto`（或 `make gen`）
3. 在 `internal/service/checkin/app.go` 暴露方法（调 `internal/biz/checkin`）
4. 新建 `api/moehttp/checkin_compat.go`，`RegisterCheckinCompat`
5. 在 `register_all.go` 调用；路径加入 `scripts/gen/http-routes` 的 `skipExactPaths`
6. `make gen-http-routes`（确认 `native=0`）
7. `make check` + 手测
8. 无引用后删除对应 `api/internal/logic/<group>`（**勿**先删 defs）

**下一批**与 §0 表一致；并行拆分见 [kratos-migration-status.md §下一步](./kratos-migration-status.md#下一步next)。

---

## 6. 风险与纪律

- **每域一个 PR**，避免与 `make gen-api` 大范围冲突
- 路径、JSON 字段与现网 **完全一致**（Flutter / moe-admin 无感）
- 新能力走 [new-api-kratos.md](./new-api-kratos.md)，**勿**在迁移同时扩 `api/defs`
- `make gen-http-routes` 后应保持 **`nativeDomainRouteCount == 0`**

---

## 7. 完成定义

### 传输层（已达）

- [x] 全部存量路径在 Kratos `RegisterAll` 注册
- [x] `routes_native_gen` = 0
- [x] 仅 swagger bridge = 2

### 域级 Done（实现层）

- [ ] HTTP 在 `*_compat.go` 直挂 `internal/service`（或官方 Kratos service）
- [ ] `skipExactPaths` 含该域所有 path
- [ ] `api/<domain>/v1/*.proto` 为契约 SSOT
- [ ] 对应 `api/internal/logic/<group>` 无活跃引用
- [ ] `make check` 通过

### 全站实现层 100%

- [ ] 263 条 compat 均为分档 **A**（直挂 App）
- [ ] 仅保留 swagger bridge（2）及不可避免的 WS/流式 handler 包装

---

## 8. 相关命令

```bash
cd backend
make gen-moe-proto    # 域 proto → *.pb.go
make gen-http-routes  # 同步 routes_*_gen（应保持 native=0）
make check            # 编译 + moehttp / kratosprogress 单测
make moe-social
curl -s http://127.0.0.1:8888/migration | jq .
```
