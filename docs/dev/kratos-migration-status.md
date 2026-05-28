# Kratos 迁移 — 进度清单

> **更新：2026-05-28**
> **当前阶段：PK 纯 Kratos 落地（PK-0 ✅）** · FS-9 / F 已完成  
> **全站迁移 F（biz+GW）：~100%** · **工程终态 G：~82%**（传输 PK 进行中）  
> **行动 SSOT**：[kratos-pure-rollout.md](./kratos-pure-rollout.md)
> 口径：[kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义) · 路线图：[kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md) · 架构 SSOT：[kratos-migration.md](./kratos-migration.md)

---

## 总览

| 曲线 | 进度 | 验收 |
|------|------|------|
| A · Hybrid Moe | **100%** | `make verify-moe-complete` |
| B · 纯 Kratos 试点 | **100%** | `make verify-kratos-100` |
| **F · biz+GW 下沉** | **~100%** | `make verify-sprint-f112` |
| G · 工程现代化就绪 | **~78%** | Hybrid 可上线；≠ 契约拆分完成 |

**F=100% 定义**：各域 biz 100% + 域 proto 拆分（FS-8）+ 退役 `super.*`（FS-9）+ RPC logic 零直写 DB（FS-10）

**F 契约层完成**：`api/moe.api` + `rpc/moe.proto`（defs 分片 SSOT）；`make verify-sprint-fs9`。运行时 **单进程 Hybrid**：`make moe-social` → HTTP :8888 + 内网 gRPC :8080（见 [moe-social-runtime.md](./moe-social-runtime.md)）。

---

## 当前生产架构（`make moe-social`）

| 网关 | 路由 | 覆盖 |
|------|------|------|
| `moeadmingw` | in_process | Moe Admin / Brain / 工具 |
| `vipadmingw` | in_process | VIP 套餐 CRUD |
| `usergw` | in_process | 登录/社交/通知 + VIP/钱包/OAuth/设备/用户 CRUD **尾巴** |
| `admingw` | in_process | **全 Admin HTTP**（moderation/accounts/growth/orders/dashboard/insights/CRUD） |
| `aigw` | in_process | providers/agents/lorebooks + public agents |
| `llmgw` | in_process | models/catalog/chat-turn/推理 + **记忆读/删/反馈/向量/图谱** |
| `chatgw` | in_process | SendPrivateMessage + ListPrivateMessages / ListPrivateConversations |
| `postgw` / `commentgw` / `communitygw` / `giftgw` / `achievementgw` | in_process | 社交写读（F90–F100d） |
| `landinggw` / `behaviorgw` | in_process | Landing / 行为埋点 |
| `super.*` | deprecated | HTTP/RPC 契约仍生成 goctl；新域见 `api/<domain>/v1/*.proto` stub |

进程入口：`backend/internal/platform/moesocial/run.go` — 单进程 **HTTP :8888** + 内网 **gRPC :8080**。

---

## 各域域内进度（F109 后）

| 域 | 域内 % | 说明 |
|----|--------|------|
| Moe | **100%** | `biz/moe` + `moeadmingw` |
| VIP 套餐 | **100%** | `biz/vip` + `vipadmingw` |
| User | **100%** | F109：`user/` logic 零 SuperRpc；含 OAuth/设备/钱包 |
| Admin（非 Moe） | **100%** | F108：admin logic 零 SuperRpc |
| AI | **100%** | F110：用户记忆配置 HTTP → `llmgw` |
| LLM | **100%** | 推理 + memory 写/读/向量/图谱 in_process |
| 社交 | **100%** | post/comment/community/gift；Moe 工具 execute → `moeadmingw` |
| 实时 / 通知 | **100%** | F112：Voice UserGW 收口；离线通知 local-first |
| 其它 | **100%** | landing/behavior/appcfg/checkin/achievement |
| 平台 | **100%** | `moe-social` 单二进制编排 |

---

## HTTP SuperRpc（F110 ✅）

`api/internal/logic/**` 已 **零 `SuperRpcClient`**（2026-05-28）。GW 透传/本地优先：

| 路径 | 归属 |
|------|------|
| `avatar/*` | `usergw`（`gateway_f110.go`） |
| `ai/userconfiglogic.go` / `putaimemorysettingslogic.go` | `llmgw`（含 `UpsertAiUserConfig`） |
| `admin_public/*` | `admingw`（`gateway_public.go`） |
| `moe/executemoetoollogic.go` | `moeadmingw`（`gateway_tools.go`） |
| `chat/private_chat_delivery.go` | `notifybiz` 或 `usergw.CreateNotification` |

验收：`make verify-sprint-f110`

---

## Sprint 时间线（F70 → F109）

| Sprint | 日期 | 要点 | 验收 |
|--------|------|------|------|
| **F70** | — | Landing / VIP 订单 / Admin 只读 / notify | `verify-sprint-f70` |
| **F80–F100d** | — | 社交 / community / gift / llm 读 | `verify-sprint-regression` |
| **F101** | 05-28 | Admin list + 话题 bootstrap | `verify-sprint-f101-admin` |
| **F102** | 05-28 | Admin/成就/菜单写 + memory 写 | `verify-sprint-f102-admin-memory` |
| **F103** | 05-28 | LLM chat 推理 biz 化 | `verify-sprint-f103-llm-inference` |
| **F104** | 05-28 | Admin insights/topic/tags | `verify-sprint-f104-admin-insights` |
| **F105** | 05-28 | AI agents/resources → `aigw` | 含于 `verify-sprint-f100-final` |
| **F106** | 05-28 | Chat SendPrivateMessage → `chatgw` | 含于 `verify-sprint-f100-final` |
| **F107** | 05-28 | 私信 List* + Voice UserGW | `verify-sprint-f107-chat-read` |
| **F108** | 05-28 | Admin 尾巴 29 接口 → `admingw` | `verify-sprint-f108-admin-tail` |
| **F109** | 05-28 | User 尾巴 ~33 + LLM 记忆读 → `usergw`/`llmgw` | `verify-sprint-f109-user-tail` |
| **F110** | 05-28 | HTTP logic 零 SuperRpc → GW 透传 | `verify-sprint-f110` |
| **F111** | 05-28 | 审计写/虚拟形象/Moe 工具 local-first | `verify-sprint-f111` |
| **F112** | 05-28 | Admin 登录/AI 配置 GW + Voice 收口；GW 零 super-only | `verify-sprint-f112` |
| FS-8/9 | 05-28 | 域 proto stub + super deprecated 头 | `verify-sprint-f100-final` |

---

## 已完成 ✅（摘要）

### F112 — HTTP/GW 收尾

- [x] `admingw` AdminLogin / AdminBootstrapAccount → `biz/admin/auth`
- [x] `llmgw` Get/UpsertAiUserConfig → `biz/ai` + `llmapp`
- [x] Voice `ResolveVoiceUserDisplay` + UserGW（`verify-gw-local-first` 全 GW local-first）
- [x] `make verify-sprint-f112`

### F111 — GW 小域闭环

- [x] 管理审计写 → `biz/admin` + `admingw`；`TryRecordAdminAudit` 不再走 `SuperRpcClient`
- [x] 虚拟形象 → `biz/user/avatar` + `usergw` local-first；RPC 薄层
- [x] Moe `ExecuteTool` → `moeadmingw` 进程内优先
- [x] 剩余盘点：[kratos-migration-backlog.md](./kratos-migration-backlog.md)

### F110 — HTTP 零 SuperRpc

- [x] Avatar / Admin 公开登录 / Moe 工具 / AI 用户配置 → 对应 `*gw`
- [x] 私信离线通知回退 → `usergw.CreateNotification`（本地 DB 优先 `notifybiz`）
- [x] `api/internal/logic/**` 零 `SuperRpcClient` · `make verify-sprint-f110`

### F109 — User 尾巴

- [x] User ~33 接口 → `biz/user`（profile/VIP/wallet/OAuth/devices）+ `usergw`
- [x] LLM 记忆读/删/反馈/向量/图谱 → `biz/llm` + `llmgw` local-first
- [x] `api/internal/logic/user/**` 零 `SuperRpcClient`

### F108 — Admin 尾巴

- [x] Admin 29 接口 → `biz/admin` + `admingw`
- [x] `api/internal/logic/admin/**` 零 `SuperRpcClient`

### F104–F107 — 核心域收口

- [x] Admin insights · AI agents · Chat 私信读写 · Voice 边界文档

更早批次（F70–F100d）：见 [kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md)、[kratos-migration-sprint-f70.md](./kratos-migration-sprint-f70.md)（历史）。

---

## 纯 Kratos 落地（PK）

| 阶段 | 状态 | 验收 |
|------|------|------|
| PK-0 基线 | ✅ | `make verify-kratos-rollout-pk0` |
| PK-1 契约纪律 | ✅ | `make verify-kratos-rollout-pk1` · `api/README.md` |
| PK-2 Moe/VIP 灰度 | ✅ | `kratos_admin_http_enabled` + `kratos_vip_http_enabled` · `make verify-kratos-rollout-pk2` |
| PK-3 按域扩 Kratos | ⬜ | 见 rollout §3 顺序 |
| PK-4/5 换传输 / 退役 goctl | ⬜ | 未排期 |

手册：[kratos-pure-rollout.md](./kratos-pure-rollout.md)

---

## 待办 ⬜（可选）

| 优先级 | 项 | 说明 |
|--------|-----|------|
| FS-9b | `pb/super` 包名重命名 | PK-5 或独立 sprint |
| 可选 | `voicegw` | 信令 biz 化，见 [voice-ws-boundary.md](./voice-ws-boundary.md) |

---

## 日常命令

```bash
cd backend

# PK 纯 Kratos（PK-1 + PK-2 完成）
make verify-kratos-rollout-pk12
make verify-kratos-rollout-pk0
make verify-kratos-100

# FS-9 全契约 + 单进程回归
make verify-sprint-fs9

# FS-8 / FS-8b 分项
make verify-sprint-fs8b
make verify-sprint-fs8

# FS-10 RPC 薄层
make verify-sprint-fs10

# F112 回归
make verify-sprint-f112
make verify-sprint-f111
make verify-sprint-f110
make verify-sprint-f109-user-tail
make verify-sprint-f108-admin-tail

# 近期 sprint
make verify-sprint-f107-chat-read
make verify-sprint-f104-admin-insights
make verify-sprint-f102-admin-memory
make verify-sprint-f101-f103          # Windows 友好
make verify-sprint-f100-final

# 全量 Hybrid 回归
make verify-sprint-regression
make moe-social-stop && make moe-social
```

Windows 无 bash 时：

```powershell
powershell -File scripts/verify-sprint-f109-user-tail.ps1
powershell -File scripts/verify-sprint-f108-admin-tail.ps1
powershell -File scripts/verify-sprint-f102-admin-memory.ps1
```
