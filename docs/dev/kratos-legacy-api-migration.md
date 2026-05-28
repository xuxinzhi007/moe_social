# 存量 HTTP 接口迁移评估（2026-05-27）

> SSOT 架构：[kratos-migration.md](./kratos-migration.md) · 新接口：[new-api-kratos.md](./new-api-kratos.md) · 进度勾选：[kratos-migration-status.md](./kratos-migration-status.md)

## 结论（当前状态）

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

**下一批建议优先级**（适合 **多子代理 + git worktree** 并行，见 [parallel-agent-workflow.md](../guidelines/parallel-agent-workflow.md)）：

1. `admin_service_compat` → 直调 `AdminApp`（55 条，收益最大）
2. `user_compat` → `UserApp`（49 条，按子域拆 PR）
3. `ai_compat` / 私信 → `AIApp` / `ChatApp`
4. `platform_compat` LLM 写路径 → `LLMApp`（chat 逻辑重，可后置）

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
