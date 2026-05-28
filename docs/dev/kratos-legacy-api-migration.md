# 存量 HTTP 接口迁移评估

> **状态快照更新：2026-05-28**（P3 + P5 完成）  
> **状态板（勾选 / 汇报用）**：[kratos-migration-status.md](./kratos-migration-status.md)  
> SSOT 架构：[kratos-migration.md](./kratos-migration.md) · 新接口：[new-api-kratos.md](./new-api-kratos.md) · P5-D：[kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md)  
> §0 与状态板数字不一致时，**以 `route_stats.go` + `make check` 为准**，并同步两处文档。

---

## 0. 状态快照（Now → Next）

### 0.1 当前状态（Latest · 2026-05-28）

**阶段名：P3 + P4 + P5 完成 — 存量 HTTP 迁移已收口**

| 维度 | 状态 | 说明 |
|------|------|------|
| **传输 / 路由注册** | ✅ | compat **263**；`native_gen=0`；`bridge=2` |
| **实现层** | ✅ | `*_compat.go` → `internal/service/*App` → `internal/biz` |
| **`api/internal/logic`** | ✅ **0** 文件 | 已物理删除；`make audit-logic-orphans` 通过 |
| **`rpc/internal/logic`** | ✅ **0** 文件 | P5-B；`moe.proto` 无 `service Super` |
| **生产零 go-zero** | ✅ | P5-D：`go list -deps ./cmd/moe-social` 无 go-zero |
| **工程验收** | ✅ | `make check` · `/migration percent=100` |

**代码锚点**

```text
backend/api/moehttp/register_all.go    # 注册入口
backend/api/moehttp/route_stats.go     # PilotNativeCompatRoutes = 263
backend/api/moehttp/routes_native_gen.go  # nativeDomainRouteCount = 0
backend/api/internal/logic/            # .gitkeep（已退役）
```

---

### 0.2 下一步（维护向）

HTTP 存量迁移**不再**是主轨道。见 [kratos-migration-status.md §下一步](./kratos-migration-status.md#下一步next)：

| 优先级 | 任务 |
|--------|------|
| 1 | grpc 冒烟 notify / chat / vip |
| 2 | 分体 api/rpc 联调（若需要） |
| 3 | 可选：从 `go.mod` 移除 go-zero（需废弃 hybrid 或拆 module） |

新能力：**只**走 [new-api-kratos.md](./new-api-kratos.md)（域 proto + `internal/service`）。

---

### 0.3 阶段对照（一眼看懂）

```text
[已完成] PK / 传输层      Kratos :8888 全路由 + native_gen=0
[已完成] compat 263       分文件注册 + 直挂 service/biz
[已完成] api logic 清库   0 文件
[已完成] P5 Super 退役    无 Super gRPC · gateway 无 SuperClient
[已完成] P5-D 生产依赖    moe-social 依赖树零 go-zero
[保持]   bridge=2         swagger
[可选]   hybrid 回滚      go build -tags hybrid
```

---

## 结论（汇总表）

| 项 | 状态 |
|----|------|
| 传输层 Kratos :8888 | ✅ 268 条 goctl 路由均在 Kratos 注册 |
| `routes_native_gen` | ✅ **0** |
| `routes_bridge_gen` | **2**（swagger） |
| `api/moehttp/*_compat.go` | ✅ **263** 条（`PilotNativeCompatRoutes`） |
| 实现层 | ✅ 经 `internal/service` / `internal/biz`（**无** `api/internal/logic`） |
| 生产 go-zero 依赖 | ✅ **0**（P5-D） |

本文 §2 保留 **compat 文件级路由表**（改路由前对表用）；进度汇报以状态板为准。

---

## 1. 三套「进度」不要混

| 口径 | 典型值 | 含义 |
|------|--------|------|
| `GET /migration` → `percent` | **100** | 传输 + biz/GW + 路由挂 Kratos + logic 清库 |
| `rollout_percent` | **100** | 传输铺轨 |
| **生产零 go-zero** | **达标** | `go list -deps ./cmd/moe-social` 无 `zeromicro/go-zero`（**不**等于仓库删光 go-zero 源文件） |

代码口径：`backend/api/moehttp/route_stats.go`、`backend/internal/platform/kratosprogress/`。

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
| `user_compat.go` | 49 | 直挂 | `UserApp` |
| `user_memory_compat.go` | 8 | 直挂 | `LLMApp` / 记忆 biz |
| `ai_compat.go` | 14 | 直挂 | `AIApp` |
| `chat_compat.go` | 9 | 直挂 | `ChatApp` + WS biz |
| `wave2_misc_compat.go` | 27 | 直挂 | 杂项 service |
| `admin_service_compat.go` | 55 | 直挂 | `AdminApp` |
| `admin_legacy_compat.go` | 28 | 直挂 | Moe brain/flow、运行时、媒体等 |
| `platform_compat.go` | 17 | 直挂 | `LLMApp` / platform service |

共享辅助：`compat_invoke.go`（遗留命名；生产路径调 `*App`，非 `api/internal/logic`）。

**已删除（勿再引用）**：`user_logic_compat.go`、`wave2_logic_compat.go`、`platform_logic_compat.go`、`admin_logic_compat.go`（admin 已拆为 `admin_service_compat` + `admin_legacy_compat`）。

### 2.2 实现层（263 条 · P3 后）

| 分档 | 数量 | 说明 |
|------|------|------|
| **生产路径** | **263** | `*_compat.go` → `internal/service/*App` → `internal/biz` |
| **已退役** | **0** | `api/internal/logic` 无业务文件 |
| **Hybrid 回滚** | 可选 | `api/internal/handler/**` 仅 `//go:build hybrid` |

历史分档 A/B/C（logic 薄转）见 [archive/dev/kratos/](../archive/dev/kratos/) 冲刺文档。

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

## 7. 完成定义（已达）

### 传输层

- [x] 全部存量路径在 Kratos `RegisterAll` 注册
- [x] `routes_native_gen` = 0
- [x] 仅 swagger bridge = 2

### 实现层（P3）

- [x] 263 条 compat 经 `internal/service` / `internal/biz`
- [x] `api/internal/logic` 无业务文件
- [x] `make check` + `/migration percent=100`

### P5

- [x] 无 `service Super` · `rpc/internal/logic` 清库
- [x] 生产 `moe-social` 依赖树零 go-zero（P5-D）

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
