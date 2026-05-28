# 全站迁移 — 剩余工作盘点（F110 后）

> **更新：2026-05-28** · SSOT 进度：[kratos-migration-status.md](./kratos-migration-status.md)  
> **更新：2026-05-27** · **F/FS-8～10 ✅** · **下一执行：PK 纯 Kratos** — [kratos-pure-rollout.md](./kratos-pure-rollout.md)

---

## 1. 三层剩余量（一眼看懂）

| 层级 | 状态 | 量级 | 说明 |
|------|------|------|------|
| **L1 HTTP logic** | ✅ **100%** | 0 文件 | F110：`api/internal/logic/**` 零 `SuperRpcClient` |
| **L2 API 网关 local-first** | ✅ **100%** | 0 个 super-only 方法 | F112：`verify-gw-local-first.sh` |
| **L3 RPC `super` 服务** | ✅ **薄层** | **215** 个 logic `.go` · 零直写 GORM | FS-10：`make verify-sprint-fs10` |
| **L4 契约** | ✅ **FS-9** | `moe.api` / `moe.proto` + defs | 0 |
| **L5 可选 Voice** | ⬜ | 信令 WS | 见 [voice-ws-boundary.md](./voice-ws-boundary.md) |

**巨大项（留最后）**：FS-8 按域切 goctl、FS-9 删 `super.*`、FS-10 全量 RPC 薄层化。  
**可小步做完**：GW local-first 尾巴、RPC 单方法 biz 化、`admin_public` 登录 biz、memory helper 清理。

---

## 2. F 曲线：还差多少到 100%

| 桶 | 权重 | F110 域内 | 终态条件 | 缺口 |
|----|------|-----------|----------|------|
| Moe / VIP / User / Admin / 社交 / AI·LLM / 其它 / 平台 | 92% | **100%** | biz+GW HTTP 完成 | 0 |
| 实时 / 通知 | 8% | **~95%** | Voice 可选 biz 化 | ~0.4% F |
| **契约 FS-8 HTTP** | — | ✅ `api/defs` + `verify-sprint-fs8` | 0 |
| **契约 FS-8b RPC** | — | ✅ `rpc/defs` + `verify-sprint-fs8b` | 0 |
| **退役 FS-9** | — | ✅ 无 `super.api`/`super.proto` 文件 | `pb/super` import 保留 |
| **RPC FS-10** | — | ✅ 完成 | `verify-sprint-fs10` | 0 |

**合计（biz+GW 口径）**：**~99% → 100%** 只差实时域收尾 + 文档口径对齐；**不等于**可删 `super.proto`。

---

## 3. 按优先级分批（建议执行顺序）

### P0 — 小步可闭环（F111 + F112 ✅）

| 项 | 改动 | 验收 |
|----|------|------|
| 管理审计写 | `biz/admin/audit_write` + `admingw` + `TryRecordAdminAudit` → `AdminGW` | `make verify-sprint-f111` |
| 虚拟形象 | `biz/user/avatar` + `usergw` local-first + RPC 薄层 | 同上 |
| Moe 工具执行 | `moeadmingw.MoeExecuteTool` → 进程内 `ExecuteTool` | 同上 |
| Admin 登录/引导 | `biz/admin/auth` + `admingw` | `verify-sprint-f112` |
| LLM AI 用户配置 | `biz/ai/user_config` + `llmgw` | 同上 |
| Voice 展示名 | `ResolveVoiceUserDisplay` | 同上 |

### P1 — goctl 卫生（F113 ✅）

| 项 | 说明 |
|----|------|
| `prune-api/rpc-logic-shells.sh` 增强 | 删未引用 todo + manifest 孤儿 |
| `verify-gen-hygiene` | `make gen` 后验收 |
| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | 根因与 FS-8 关系 |
| `api/defs/README.md` | FS-8 契约分片目录准备 |

### P2 — 中小（下一批建议）
| RPC memory helper 删除 | 小 | `rpc/internal/logic/memory_*` 无引用则删 |
| `achievement` RPC | 小 | 保持 RPC 薄层（不宜 `biz` import `rpc/internal`） |

### P2 — 大（FS-10 分段）

| 项 | 量级 | 说明 |
|----|------|------|
| RPC Admin 读列表 | 大 | `admin_*logic.go` 仍多直写 DB → `biz/admin` |
| RPC LLM memory 存储 | 大 | `memory_embedding_*` / `memory_relation_*` |
| RPC 社交 helper | 中 | `posthelpers.go` 等 |

### P3 — 巨大（最后）

| 项 | 说明 |
|----|------|
| **FS-8** | 域 `*.proto` 替代 `super.api` 生成 HTTP；需全链路回归 |
| **FS-9** | 删除 `super.api` / `super.proto` / `pb/super` |
| **voicegw** | 可选；非 F 公式硬性项 |

---

## 4. 代码实测锚点（2026-05-28）

```bash
cd backend
# HTTP logic 零 SuperRpc
! grep -r SuperRpcClient api/internal/logic/

# API 层仍引用 SuperRpc（注入/审计已迁）
grep -r SuperRpcClient api/internal --include='*.go'

# RPC 直写 DB 约 35 文件（含 helper）
grep -l '\.DB\|gorm\.' rpc/internal/logic/*.go | wc -l

# 域 proto stub（未切 goctl）
ls api/*/v1/*.proto
```

---

## 5. 日常验收

```bash
make verify-sprint-f112    # GW 全 local-first + F112 域
make verify-sprint-f110    # HTTP 零 SuperRpc
make verify-sprint-f111    # F111 小域闭环
make verify-sprint-regression
```
