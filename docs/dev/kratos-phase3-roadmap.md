# Phase 3+ 路线图索引

> **更新：2026-05-27** · **当前阶段：FS-3b**

---

## 进度一览

| 里程碑 | 代号 | 进度 | 文档 |
|--------|------|------|------|
| Hybrid Moe | **A** | **100%** | [kratos-migration.md](./kratos-migration.md) |
| 纯 Kratos 试点方案 | **B** | **100%** | [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) |
| VIP 套餐域 | FS-2 | **100%** | [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md) |
| User 核心 | FS-3a | **✅** | 同上 |
| **全站迁移** | **F** | **~48%** | 同上 §1 |
| 工程就绪度 | **G** | **~55%** | 同上 §1.4 |

---

## 当前阶段：FS-3b

**目标**：User 扩展（关注/好友、用户侧 VIP 订单、记忆、OAuth）下沉 `biz/user`，将 **F 提升至 50%+**。

**已完成（本阶段之前）**：

- FS-2：`biz/vip` + `vipadmingw`
- FS-3a：`biz/user` + `usergw`（login、register、getUserInfo、getUser、getUserVipStatus、checkUserVip）
- 平台：`make verify-platform` / `bin/moe-social`

**下一域（之后）**：FS-4 Admin 非 Moe。

---

## 架构（生产，简图）

```text
:8888  go-zero API
         ├─ moeadmingw  → biz/moe     (in_process)
         ├─ vipadmingw  → biz/vip     (in_process)
         ├─ usergw      → biz/user    (in_process，核心子集)
         └─ logic       → :8080 RPC   (legacy + 已转调 biz 的 RPC)

:8080  zrpc — super.Super + moe.v1.MoeAdmin
```

详见 [kratos-migration.md §1.1](./kratos-migration.md#11-生产架构图2026-05-27)。

---

## 验收命令

```bash
cd backend
make moe-social              # 日常；日志应见三网关 in_process
make verify-full-site-50     # F≈48%
make verify-domain-user      # FS-3a
make verify-domain-vip       # FS-2
make verify-moe-complete     # A
make verify-kratos-100       # B
make build-moe-social
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
