# Phase 3+ 路线图索引

> **更新：2026-05-27** · **F/FS 完成** · **当前执行：PK 纯 Kratos 落地**  
> **行动 SSOT**：[kratos-pure-rollout.md](./kratos-pure-rollout.md) · **勾选**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 进度一览

| 里程碑 | 代号 | 进度 | 文档 |
|--------|------|------|------|
| Hybrid Moe | **A** | **100%** | [kratos-migration.md](./kratos-migration.md) |
| 纯 Kratos 试点方案 | **B** | **100%** | [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) |
| VIP / User / Admin HTTP | FS-2～4 | **100%** | [kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md) |
| **全站迁移 biz+GW** | **F** | **~100%** | [kratos-migration-status.md](./kratos-migration-status.md) |
| 契约 FS-8/8b/9/10 | **FS** | **✅** | `make verify-sprint-fs9` |
| **纯 Kratos 落地 PK** | **PK** | **PK-0 ✅** | [kratos-pure-rollout.md](./kratos-pure-rollout.md) |
| 工程终态 G | **G** | **~82%** | 传输仍 Hybrid；PK-4+ 换 go-zero |

---

## 当前阶段：PK-1（纯 Kratos 契约纪律）

**目标**：新接口只进 `api/<domain>/v1/*.proto`；扩展现有 `moekratos` 注册。见 [kratos-pure-rollout.md §3](./kratos-pure-rollout.md#3-pk-阶段执行顺序)。

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
