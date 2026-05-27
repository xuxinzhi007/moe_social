# Kratos 迁移 — 进度清单

> **更新：2026-05-28**
> **当前阶段：Sprint F109 完成** → 下一批 **F110（HTTP 零 SuperRpc 收口）**
> **全站迁移 F（biz+GW）：~98%** · **工程就绪度 G：~78%**
> 口径：[kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义) · 路线图：[kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md) · 架构 SSOT：[kratos-migration.md](./kratos-migration.md)

---

## 总览

| 曲线 | 进度 | 验收 |
|------|------|------|
| A · Hybrid Moe | **100%** | `make verify-moe-complete` |
| B · 纯 Kratos 试点 | **100%** | `make verify-kratos-100` |
| **F · biz+GW 下沉** | **~98%** | `make verify-sprint-f109-user-tail` |
| G · 工程现代化就绪 | **~78%** | Hybrid 可上线；≠ 契约拆分完成 |

**F=100% 定义**：各域 biz 100% + 域 proto 拆分（FS-8）+ 退役 `super.*`（FS-9）+ RPC logic 零直写 DB（FS-10）

**≠ F109 已完成全站 100%**：HTTP 主路径已 in_process；仍有 **~8 个 logic 文件** 走 `SuperRpcClient`（见下表）；`super.api` / `super.proto` 仍为 goctl SSOT。

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
| AI | **~92%** | F105 agents/resources；**AI 用户记忆配置** HTTP 仍 SuperRpc |
| LLM | **100%** | 推理 + memory 写/读/向量/图谱 in_process |
| 社交 | **~95%** | post/comment/community/gift；Moe 工具 execute 仍 SuperRpc |
| 实时 / 通知 | **~90%** | chatgw 私信；Voice 边界已文档化；投递 notify 有 SuperRpc 回退 |
| 其它 | **100%** | landing/behavior/appcfg/checkin/achievement |
| 平台 | **100%** | `moe-social` 单二进制编排 |

---

## HTTP SuperRpc 残留（F110 目标）

`api/internal/logic` 中仍引用 `SuperRpcClient` 的文件（2026-05-28 实测）：

| 路径 | 方法 | 建议归属 |
|------|------|----------|
| `avatar/getuseravatarlogic.go` | GetUserAvatar | `usergw` |
| `avatar/updateuseravatarlogic.go` | UpdateUserAvatar | `usergw` |
| `ai/userconfiglogic.go` | Get/UpsertAiUserConfig | `aigw` / `llmgw` |
| `ai/putaimemorysettingslogic.go` | Get/UpsertAiUserConfig | 同上 |
| `admin_public/adminloginlogic.go` | AdminLogin | `admingw` |
| `admin_public/adminbootstrapaccountlogic.go` | AdminBootstrapAccount | `admingw` |
| `moe/executemoetoollogic.go` | MoeExecuteTool | `moeadmingw` |
| `chat/private_chat_delivery.go` | CreateNotification（回退分支） | `usergw` / notify biz |

验收目标：`grep -r SuperRpcClient api/internal/logic/` → **0**（`make verify-sprint-f110` 待建）。

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
| FS-8/9 | 05-28 | 域 proto stub + super deprecated 头 | `verify-sprint-f100-final` |

---

## 已完成 ✅（摘要）

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

## 待办 ⬜

| 优先级 | 项 | 说明 |
|--------|-----|------|
| **P0** | **F110** | 上表 ~8 文件 → 对应 GW；HTTP 零 SuperRpc |
| P1 | RPC 清理 | 删除 `rpc/internal/logic` 中已无引用的 memory helper |
| P1 | FS-8 | 按域切 goctl 至 `api/<domain>/v1/*.proto`（当前仅 stub） |
| P2 | FS-9 | 物理删除 `super.api` / `super.proto`（需零 super 调用） |
| P2 | FS-10 | RPC logic 薄层化 + 零直写 DB |
| 可选 | `voicegw` | 信令 biz 化，见 [voice-ws-boundary.md](./voice-ws-boundary.md) |

---

## 日常命令

```bash
cd backend

# 当前批次（F109 回归）
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
