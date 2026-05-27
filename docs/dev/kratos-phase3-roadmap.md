# Phase 3+ 路线图索引

> 更新：**2026-05-27**

| 里程碑 | 进度 | 文档 |
|--------|------|------|
| Hybrid Moe（A） | **100%** | [kratos-migration.md](./kratos-migration.md) |
| 纯 Kratos 试点方案（B） | **100%** | [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) |
| **全站迁移（F）** | **~22%** | **[kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md)** |
| 工程就绪度（G） | **~48%** | 同上 §1.4 |

## 当前阶段

**FS-0 准备** → 下一业务域建议 **FS-2 VIP 全量**。

## 验收

```bash
cd backend
make moe-social              # 日常 / 生产 HTTP :8888
make verify-kratos-100       # B + Hybrid 回归
make build-moe-social        # bin/moe-social
```

## 文档树

```text
kratos-migration.md              # Hybrid SSOT + F/G 口径
kratos-full-site-migration-plan.md   # 全站 FS-0～FS-8（主执行）
kratos-pure-migration-plan.md    # 试点 B（已完成）
kratos-hybrid-migration-plan.md  # Moe 纪律
kratos-migration-status.md       # 勾选清单
```
