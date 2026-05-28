# 全站迁移路线图：F70 → F100+

> **起点**：F ≈ **70%**（Sprint F70 完成，2026-05 初）  
> **当前**：F ≈ **100%**（**F112 完成**，2026-05-28）  
> **终态**：F = **100%**（各域 biz 化 + 域契约拆分 + 可退役 `super.*`）  
> **原则**：小步迁移 · 每批 `make verify-sprint-fNN` · 不凑权重数字  
> **勾选清单**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 当前阶段（2026-05-28）

| 项 | 状态 |
|----|------|
| Admin / User HTTP | ✅ logic 目录零 SuperRpc（F108 + F109） |
| **全 HTTP logic** | ✅ F110：`api/internal/logic/**` 零 SuperRpc |
| LLM 记忆全路径 | ✅ 写 + 读 + 向量/图谱 in_process |
| AI agents / Chat 私信 | ✅ aigw / chatgw |
| **FS-8/9** | proto stub + deprecated 头；goctl 仍用 `super.*` |

**下一 Sprint FS-8**：按域切 goctl 契约；见 [kratos-migration-status.md](./kratos-migration-status.md)。

---

## 进度公式（不变）

```text
F = Σ (域权重 × 域内进度)
域内进度：0 → 20 → 60 → 100
```

| 域 | 权重 | F70 域内 | **F110 域内** | F100 目标 |
|----|------|----------|---------------|-----------|
| Moe | 12% | 100% | **100%** | 100% |
| VIP | 8% | 100% | **100%** | 100% |
| User | 20% | ~98% | **100%** | 100% |
| Admin（非 Moe） | 14% | ~35% | **100%** | 100% |
| 社交 | 18% | 0% | **100%** | 100% |
| AI / LLM | 14% | 0% | **100%** | 100% |
| 实时 / 通知 | 8% | ~30% | **~95%** | 100% |
| 其它 | 6% | 100% | **100%** | 100% |
| 平台 | 10% | 100% | **100%** | 100% |

**F70 合计 ≈ 70%** · **F109 合计 ≈ 98%** · **F110 合计 ≈ 99%** · **F100 终态 = 100%**（含 FS-8～10）

---

## Sprint 时间线

### F70 ✅ — 起点 +10%

| 步 | 内容 | ΔF |
|----|------|-----|
| S1 | Landing → `landinggw` | +0.5% |
| S2 | User VIP 订单 | +1% |
| S3 | Admin 只读 3 接口 | +4% |
| S4 | appcfg/doc + behavior | +1% |
| S5 | Admin notify → `biz/notify` | +2.5% |

验收：`make verify-sprint-f70` · 详述：[kratos-migration-sprint-f70.md](./kratos-migration-sprint-f70.md)

### F80 → F100d ✅ — 社交 / community / gift / llm 读

| 阶段 | 内容 |
|------|------|
| F80 | User notify、Admin 公告只读、Post search |
| F90 | Comment/Post CRUD、Admin 公告写 |
| F92–F96 | 社交 like/mutate |
| F97–F99 | Admin 公告写、achievement 包、checkin |
| F100a–d | gift、llm、admin gifts、community |

验收：`make verify-sprint-regression`

### F101 + F103 ✅（2026-05-28）

| Sprint | 内容 | 验收 |
|--------|------|------|
| F101 | Admin 用户/成就/菜单 list + 话题 bootstrap | `verify-sprint-f101-admin` |
| F103 | LLM chat 推理 → `biz/llm/inference` | `verify-sprint-f103-llm-inference` |

### F102 ✅（2026-05-28）

Admin 用户/成就/菜单写 + LLM memory **写**路径 → `verify-sprint-f102-admin-memory`

### F104 + F105 + F106 ✅（2026-05-28）

| Sprint | 内容 | 验收 |
|--------|------|------|
| F104 | Admin insights/topic/tags → `admingw` | `verify-sprint-f104-admin-insights` |
| F105 | AI agents → `aigw` | `verify-sprint-f100-final` |
| F106 | Chat SendPrivateMessage → `chatgw` | `verify-sprint-f100-final` |
| FS-8/9 | 域 proto stub + super deprecated | `verify-sprint-f100-final` |

### F107 ✅（2026-05-28）

私信 List* → `chatgw`；Voice UserGW + [voice-ws-boundary.md](./voice-ws-boundary.md) → `verify-sprint-f107-chat-read`

### F108 ✅（2026-05-28）

Admin 尾巴 29 接口 biz 化；`admin/` logic 零 SuperRpc → `verify-sprint-f108-admin-tail`

### F109 ✅（2026-05-28）

User 尾巴 ~33 接口 + LLM 记忆读 local；`user/` logic 零 SuperRpc → `verify-sprint-f109-user-tail`

### F110 ✅（2026-05-28）

HTTP logic 零 `SuperRpcClient`：avatar / AI config / admin_public / moe tool / chat notify → `usergw` / `llmgw` / `admingw` / `moeadmingw` → `make verify-sprint-f110`

---

## F100 终态阶段（FS-6～10）

| 阶段 | 内容 | 当前 |
|------|------|------|
| FS-6 | AI / LLM 写路径 + 工具执行 | ✅ F110 含 Moe execute GW 透传 |
| FS-7 | Chat / Voice / WS 边界 | ✅ 文档 + chatgw；Voice 可选 voicegw |
| FS-8 HTTP | `api/defs/*.api` | ✅ `make verify-sprint-fs8` |
| FS-8b RPC | `rpc/defs` + assemble | ✅ `make verify-sprint-fs8b` |
| FS-9 | 退役 `super.*` 文件名 | ✅ `make verify-sprint-fs9` |
| FS-10 | RPC 薄层 + 零 legacy 直写 DB | ✅ `make verify-sprint-fs10` |

---

## 网关清单（F109）

| 网关 | F70 | F109 |
|------|-----|------|
| `moeadmingw` | ✅ | ✅ |
| `vipadmingw` | ✅ | ✅ |
| `usergw` | ✅ 核心 | ✅ + VIP/OAuth/设备/尾巴 |
| `landinggw` / `behaviorgw` | ✅ | ✅ |
| `admingw` | 只读 | ✅ **全 Admin HTTP** |
| `postgw` / `commentgw` / `communitygw` / `giftgw` / `achievementgw` | — | ✅ |
| `llmgw` / `aigw` / `chatgw` | — | ✅ |

---

## 日常命令

```bash
cd backend

# 最新批次
make verify-sprint-f109-user-tail
make verify-sprint-f108-admin-tail

# 结构终态
make verify-sprint-f100-final
make verify-sprint-regression

# 联调
make moe-social
```

Windows：`powershell -File scripts/verify-sprint-f109-user-tail.ps1`
