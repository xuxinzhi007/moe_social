# Kratos 迁移 — 状态板（Current / Next）

> **最后更新：2026-05-28**（P3-W4b-1）  
> **读这个**：本文 = **当前状态 + 下一步** 快照

---

## 当前状态（Current）

| 阶段 | 状态 | 说明 |
|------|------|------|
| **P0–P1 传输/路由** | ✅ | compat **263** + bridge **2**（`/swagger`） |
| **P2 · 实现层直挂** | ✅ **263/263** | `*_compat.go` **零** `wrapNativeHTTP` / **零** `invokeLogicJSON` |
| **P3 · logic 退役** | 🔄 W4b 进行中 | compat 零 logic import；handler 路径 **217** logic 文件 |

### P2 分档（263 compat）

| 分档 | 条数 |
|------|------|
| A · 直挂 App/biz | **263** |
| B · invokeLogicJSON | **0** |
| C · wrapNativeHTTP | **0** |

### P3 已完成

| Wave | 内容 |
|------|------|
| **W1** | OAuth/refresh logic 删除 → `internal/biz/user` |
| **W2** | 4 条 WS → `internal/biz/chat`；`internal/pkg/presence` |
| **W3** | platform chat → `llmbiz.ExecutePlatformChat` |
| **W4a** | 删除 image logic ×4、`remotewslogic.go`；通知/admin 直调 `chatbiz`；`make audit-logic-orphans`；清理 F109 一次性脚本 |
| **W4b-1** | behavior、landing、ops、appcfg、comment handler→GW/biz；删 logic ×7（含 admin landing 代理） |
| **W4b-2** | achievement、checkin、gift、post、community handler→GW + handlerutil；删 logic ×37 |

### `/migration` 指标（勿与 rollout 混淆）

| 字段 | 含义 | 典型值 |
|------|------|--------|
| `rollout_percent` | 传输铺轨 | **100** |
| `percent` | 传输栈 85% + logic 退役 15% | **~88**（217/273 剩余） |

详见 [kratos-architecture-complete.md](./kratos-architecture-complete.md)。

### 仍存在的 legacy 层

| 路径 | 说明 |
|------|------|
| `api/internal/logic/*` | **217** 文件；handler 仍引用 ~210 Logic 类型 |
| `api/internal/handler/*` | go-zero 生成；纯 Kratos 生产 `WireOnly` 不注册 rest |
| `api/defs/*.api` | 存量契约；`make gen-api` + `prune-api-logic-shells.sh` |
| bridge 2 条 | `/swagger` |

### 验收

`make check` ✅ · `make audit-logic-orphans` → 仅 logic-only 辅助类型（如 `ResourceLogic`）

---

## 与官方 Kratos 分层对照

| 官方层 | 本仓库 | 完成度 |
|--------|--------|--------|
| **Transport** | `moekratoshttp` + `moegrpc` | ✅ |
| **Service** | `internal/service/<domain>` | ✅ |
| **Biz** | `internal/biz/<domain>` | ✅ 生产主路径 |
| **Legacy logic** | `api/internal/logic` | 🔄 随 handler 按域退役 |

**结论**：生产 HTTP **已 Kratos 化**；P3 剩余工作 = handler→biz 后删 logic，非阻塞上线。

---

## 下一步（Next）

1. **P3-W4b-3**：杂项域（emoji、avatar、vip、voice、notification…）handler→biz
2. **FS-8/9**：域 proto RPC（独立 PR）
3. **`make gen-api` 后**：`prune-api-logic-shells.sh` + 更新 `goctl-orphan-stubs.txt`

## 自检

```bash
cd backend && make check
make audit-logic-orphans
grep wrapNativeHTTP api/moehttp/*_compat.go   # 0
grep api/internal/logic api/moehttp/*.go       # 0
```
