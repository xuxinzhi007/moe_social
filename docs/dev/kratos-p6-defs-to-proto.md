# P6 — 存量 HTTP 契约迁到域 proto（defs → proto SSOT）

> **前置**：P0–P5 ✅  
> **状态板**：[kratos-migration-status.md](./kratos-migration-status.md) §P6  
> **最后同步：2026-05-29** · `go build ./...` ✅

---

## 0. 进度一览

| 指标 | 值 |
|------|-----|
| **P6 整体** | **~80%** |
| compat → App 直传 `&moe.*` | **0 处**（已全部 `*v1.FromMoe`） |
| 大域 `moe_bridge_gen.go` | **5**（admin · user · ai · llm · vip） |
| 域 `moe_bridge.go` | **10**（见下表） |
| `api/defs` 删路由（P6-C） | **未开始** |

---

## 1. 与 P3/P5 的区别

| 阶段 | 已完成 | P6 要做 |
|------|--------|---------|
| P3 | 263 路由 → compat → service → biz | — |
| P5 | 生产零 go-zero、logic 清库 | — |
| **P6** | 主域 service + compat 已 `*v1` | 契约 SSOT 在 `api/<domain>/v1`；compat 仅 types↔moe↔v1 bridge |
| **P6-C** | — | `api/defs` 注释或删除已迁 `@handler` |

---

## 2. 每域完成定义（DoD）

| # | 项 | 状态 |
|---|-----|------|
| 1 | 域 `api/<domain>/v1/*.proto`（或 `*_messages.proto`） | ✅ 主域已有 |
| 2 | `internal/service/<domain>` 签名用 `*v1` | ✅ 主域；边界可 `*FromMoe(&moe.*)` |
| 3 | `moehttp/*_compat` 调 App 用 `FromMoe` | ✅ 2026-05-29 |
| 4 | `go build ./...` | ✅ |
| 5 | `api/defs` P6 注释或删路由 | ⬜ P6-C |

---

## 3. 批次与仓库产物

### 3.1 批次状态

| 批次 | 域 | defs | proto / bridge | compat / service | 状态 |
|------|-----|------|----------------|------------------|------|
| 6-0 | behavior | `platform.api` | `behavior/v1` + `moe_bridge.go` | `behavior_compat` · service | ✅ |
| 6f | landing · achievement · checkin · comment · gift · post · community | `social.api` 等 | 各 `*/v1` + `moe_bridge.go` | `*_compat` · service · moegrpc | ✅ |
| 6f | notify（gRPC） | `user.api` | `notify/v1` + `moe_bridge.go` | `service/notify` | ✅ |
| 6g | ai · llm | `ai_llm.api` | `ai/v1` · `llm/v1` + `moe_bridge_gen.go` | `ai_compat` · `user_memory_compat` · service | ✅ |
| 6d | admin | `admin.api` | `admin/v1/admin_messages.proto` + gen | `admin_*_compat` · `admingw` · service | ✅ |
| 6e | user | `user.api` | `user/v1/user_messages.proto` + gen | `user_compat` · `user_convert` · service | ✅ |
| 6b | vip | `vip.api` | `vip/v1/vip_messages.proto` + gen | `user_compat` VIP · `vipv1`；`vip/admin_rpc` | 🟡 |
| 6h | chat | `realtime.api` | `chat/v1` + `moe_bridge.go` | `chat_compat` · service · chatgw | ✅ |
| 6a | wave2 杂项 | 多文件 | admin/user bridge | `wave2_misc_compat` | ✅ |
| 6a | platform | `platform.api` | 部分 | `platform_compat`（GW `moe.*`） | 🟡 |
| 6c | moe App | `moe.api` | `moe/v1` | platform / tool | ⬜ |

### 3.2 `moe_bridge` 文件分布

| 文件 | 域 |
|------|-----|
| `api/admin/v1/moe_bridge_gen.go` | admin（生成） |
| `api/user/v1/moe_bridge_gen.go` | user（生成） |
| `api/ai/v1/moe_bridge_gen.go` | ai（生成） |
| `api/llm/v1/moe_bridge_gen.go` | llm（生成） |
| `api/vip/v1/moe_bridge_gen.go` | vip（生成） |
| `api/behavior/v1/moe_bridge.go` | behavior |
| `api/landing/v1/moe_bridge.go` | landing |
| `api/achievement/v1/moe_bridge.go` | achievement |
| `api/checkin/v1/moe_bridge.go` | checkin |
| `api/comment/v1/moe_bridge.go` | comment |
| `api/gift/v1/moe_bridge.go` | gift |
| `api/post/v1/moe_bridge.go` | post |
| `api/community/v1/moe_bridge.go` | community |
| `api/notify/v1/moe_bridge.go` | notify |
| `api/chat/v1/moe_bridge.go` | chat |

### 3.3 `internal/service` 仍 import `rpc/pb/moe`（过渡）

仅用于 `*v1.XFromMoe(&moe.X{...})` 或 biz 返回值包装，**不是**未迁域：

| 文件 | 用途 |
|------|------|
| `admin/app.go` | 部分响应 `Admin*RespFromMoe(&moe.*)` |
| `user/app.go` · `app_tail.go` | 边界包装 |
| `post/app.go` | achievement unlock 等 |
| `notify/app.go` | gRPC 边界 |
| `vip/admin_rpc.go` | **待收尾** — 管理端 VIP CRUD |

### 3.4 compat 关键文件（P6 已桥接）

| 文件 | 域 bridge |
|------|-----------|
| `user_compat.go` | `userv1` · `vipv1` |
| `user_memory_compat.go` | `llmv1` |
| `checkin_compat.go` | `checkinv1` · `adminv1`（admin 奖励） |
| `wave2_misc_compat.go` | `adminv1` · `userv1` |
| `admin_service_compat.go` · `admin_*` | `adminv1` |
| `ai_compat.go` | `aiv1` · `llmv1` |
| 各 social `*_compat.go` | 对应 `*v1` |

**未收尾**：`platform_compat.go` — `MoeGW.MoeExecuteTool` · `UserGW.GetUser` 仍写 `&moe.*`（应在 GW 层或 compat 加 bridge）。

---

## 4. compat 桥接约定

```go
// 请求：types → moe → 域 v1 → App
rpcResp, err := app.Login(ctx, userv1.LoginReqFromMoe(&moe.LoginReq{
    Email: req.Email, Password: req.Password,
}))

// 响应：域 v1 → moe → types（复用既有 Rpc*ToTypes）
Data: userFromUserV1(rpcResp.GetUser())
```

**括号**：`FromMoe(&moe.X{...})` 闭合为 `}))`（struct `}` + `&moe)` + `FromMoe)`）。

**脚本**：`backend/scripts/gen/p6_extract_domain_proto.py` · `p6_migrate_service_file.py` · `p6_wrap_gateway.py` · `p6_fix_user_compat_once.py`

---

## 5. 单域 PR 流程

```bash
cd backend && make gen
# 1. 扩 api/<domain>/v1/*.proto
# 2. internal/service/<domain> → *v1
# 3. moehttp/*_compat → FromMoe / ToMoe
go build ./api ./rpc ./cmd/moe-social
go build ./...
```

---

## 6. 剩余工作（→ 100%）

1. **`platform_compat.go`**：`MoeGW` / `UserGW` 入参改 `*v1.FromMoe` 或 GW 内统一 bridge  
2. **`vip/admin_rpc.go`**：管理端 VIP 计划 CRUD 改 `vipv1`  
3. **P6-C**：`api/defs` 对已迁路由加 `// P6: SSOT → api/<domain>/v1` 或删除行  
4. **可选**：notify HTTP 独立走 `NotifyApp`（当前 UserApp + userv1 已可编译）

---

## 7. 相关文档

- [kratos-migration-status.md](./kratos-migration-status.md) — 汇报用总览  
- [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) — P3 263 路由  
- [new-api-kratos.md](./new-api-kratos.md) — 新接口纪律  
