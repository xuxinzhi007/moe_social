# 全站迁移路线图：F70 → F100

> **起点**：F ≈ **70%**（Sprint F70 完成）  
> **终态**：F = **100%**（各域 biz 化 + 域契约拆分 + 可退役 `super.*`）  
> **原则**：小步迁移 · 每批 `make verify-sprint-fNN` · 不凑权重数字

---

## 进度公式（不变）

```text
F = Σ (域权重 × 域内进度)
域内进度：0 → 20 → 60 → 100
```

| 域 | 权重 | F70 域内 | F100 目标 |
|----|------|----------|-----------|
| Moe | 12% | 100% | 100% |
| VIP | 8% | 100% | 100% |
| User | 20% | ~98% | 100% |
| Admin（非 Moe） | 14% | ~35% | 100% |
| 社交 | 18% | 0% | 100% |
| AI / LLM | 14% | 0% | 100% |
| 实时 / 通知 | 8% | ~30% | 100% |
| 其它 | 6% | 100% | 100% |
| 平台 | 10% | 100% | 100% |

**F70 合计 ≈ 70%** · **F100 合计 = 100%**

---

## Sprint F70 ✅（已完成）

| 步 | 内容 | ΔF |
|----|------|-----|
| S1 | Landing → `landinggw` | +0.5% |
| S2 | User VIP 订单 | +1% |
| S3 | Admin 只读 3 接口 | +4% |
| S4 | appcfg/doc + behavior `behaviorgw` | +1% |
| S5 | Admin notify → `biz/notify` | +2.5% |

验收：`make verify-sprint-f70`

---

## Sprint F80（目标 ~80%，+10%）

| 步 | 内容 | ΔF | 验收 |
|----|------|-----|------|
| **U1** | User 通知 4 接口（list/read/readall/unread）→ `biz/notify` + `usergw` | +1.6% | `verify-sprint-f80-u1` |
| **U2** | User OAuth / 记忆配置只读（若有独立 HTTP） | +0.4% | 并入 U1 或 skip |
| **A1** | Admin 公告 list/get 只读 → `biz/admin` | +2.8% | `verify-sprint-f80-a1` |
| **P1** | Post `SearchPosts` → `biz/post` + `postgw`（postpulse 已有） | +3.6% | `verify-sprint-f80-p1` |
| **N1** | 用户侧 notification HTTP 全 in_process | +1.6% | 同 U1 |

**累计验收**：`make verify-sprint-f80`

---

## Sprint F90（目标 ~90%，+10%）

| 步 | 内容 | ΔF |
|----|------|-----|
| **S1** | Comment 只读（list/get）→ `biz/comment` | +3.6% |
| **S2** | Post CRUD 核心（create/get/list）→ `biz/post` | +5.4% |
| **A2** | Admin 公告写 + audit log list → `biz/admin` | +4.2% |
| **L1** | LLM models/config 只读 → `biz/llm` | +2.8% |

优先 **只读 / 单表**；暂缓 checkin/achievement（需先抽 `internal/achievement` 包）。

**验收**：`make verify-sprint-f90`

---

## Sprint F100（目标 100%）

| 阶段 | 内容 |
|------|------|
| **FS-6** | AI / LLM 写路径 + 工具执行保留 RPC 或独立 worker |
| **FS-7** | Chat / Voice / WebSocket 与 social-core 边界清晰 |
| **FS-8** | 按域发布 `api/<domain>/v1/*.proto`；logic 仅适配 |
| **FS-9** | `super.api` / `super.proto` 标记 deprecated；无调用后删除 |
| **FS-10** | `make verify-sprint-f100` = 全域 GW + 零 legacy logic 直写 DB |

**100% 定义**：F 公式每项域内进度 = **100%**，且 FS-8 契约拆分完成。

---

## 网关清单（演进）

| 网关 | 状态 F70 | F100 |
|------|----------|------|
| `moeadmingw` | ✅ | ✅ |
| `vipadmingw` | ✅ | ✅ |
| `usergw` | ✅ | + notify |
| `landinggw` | ✅ | ✅ |
| `admingw` | ✅ 只读+notify | + 公告/audit |
| `behaviorgw` | ✅ | ✅ |
| `postgw` | — | ✅ |
| `commentgw` | — | ✅ |
| `llmgw` | — | ✅ |

---

## 日常命令

```bash
cd backend
make verify-sprint-f70    # 当前批次回归
make verify-sprint-f80    # 下一批（待实现）
make moe-social           # 联调
```

Windows 无 bash 时：`go build ./cmd/moe-social` + 对照各 `scripts/verify-sprint-*.sh` 中的 grep 项。
