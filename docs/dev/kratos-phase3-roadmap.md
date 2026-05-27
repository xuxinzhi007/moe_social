# Phase 3+ 路线图索引

> **更新：2026-05-28** · **当前阶段：F109 完成** · **F ~98%**  
> **勾选 SSOT**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 进度一览

| 里程碑 | 代号 | 进度 | 文档 |
|--------|------|------|------|
| Hybrid Moe | **A** | **100%** | [kratos-migration.md](./kratos-migration.md) |
| 纯 Kratos 试点方案 | **B** | **100%** | [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) |
| VIP / User / Admin HTTP | FS-2～4 | **100%** | [kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md) |
| **全站迁移 biz+GW** | **F** | **~98%** | [kratos-migration-status.md](./kratos-migration-status.md) |
| 工程就绪度 | **G** | **~78%** | [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md) §1.4 |
| 契约拆分 / 退役 super | FS-8/9 | **~15%** | stub 已有；goctl 仍 `super.*` |

---

## 当前阶段：F110（计划）

**目标**：HTTP 层零 `SuperRpcClient`（~8 文件）→ 见 status 清单。

**已完成（F108–F109）**：

- Admin / User logic 目录零 SuperRpc
- LLM 记忆全路径 in_process

<details>
<summary>历史：FS-3b（2026-05-27 · 已过期）</summary>

**目标**：User 扩展（关注/好友、VIP 订单、记忆、OAuth）下沉 `biz/user`，F 提升至 50%+。

</details>

---

## 架构（生产，简图）

```text
:8888  go-zero API
         ├─ moeadmingw / vipadmingw / usergw / admingw
         ├─ aigw / llmgw / chatgw / postgw / …  (in_process)
         └─ ~8 文件仍 SuperRpc（F110）

:8080  zrpc — super.Super（薄层） + moe.v1.MoeAdmin
```

详见 [kratos-migration.md §1.1](./kratos-migration.md#11-生产架构图2026-05-28)。

---

## 验收命令

```bash
cd backend
make moe-social
make verify-sprint-f109-user-tail
make verify-sprint-f108-admin-tail
make verify-sprint-regression
make verify-moe-complete
make verify-kratos-100
```

---

## 文档树

| 文件 | 用途 |
|------|------|
| [kratos-migration.md](./kratos-migration.md) | **Hybrid SSOT**、架构图、配置、命令 |
| [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md) | 全站 FS-0～FS-8、F 公式 |
| [kratos-migration-status.md](./kratos-migration-status.md) | **勾选清单** |
| [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) | 试点 B（已完成） |
| [kratos-hybrid-migration-plan.md](./kratos-hybrid-migration-plan.md) | Moe 纪律 |
