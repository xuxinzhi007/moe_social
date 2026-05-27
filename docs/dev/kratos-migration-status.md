# Kratos 迁移 — 进度清单

> 更新：**2026-05-27**  
> **全站迁移总进度 F：~22%** · **工程就绪度 G：~48%**  
> 口径说明：[kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义)

## 总览

| 曲线 | 进度 | 验收 |
|------|------|------|
| A · Hybrid Moe | **100%** | `make verify-moe-complete` |
| B · 纯 Kratos 试点方案 | **100%** | `make verify-kratos-100` |
| **F · 全站迁移** | **~22%** | 见 [全站方案](./kratos-full-site-migration-plan.md) |
| G · 工程现代化就绪 | **~48%** | 可正常开发与上线 Hybrid |

## Hybrid Moe ✅

- [x] `make verify-moe-complete` / `make moe-social` → **:8888**
- [x] `internal/biz|service|data/moe`
- [x] `moeadmingw` + `moe.proto` + `moegrpc`

## 纯 Kratos 试点方案 ✅

- [x] Phase 0～6（`moe-kratos`、Wire、`vip` 只读 @ :19032）
- [x] `make build-moe-social` → `bin/moe-social`

## 全站迁移 Phase FS（准备中）

- [x] FS-0：进度 SSOT、域清单、方案文档
- [ ] FS-1：conf/域模板/verify 脚本骨架
- [ ] FS-2：**VIP 全量**（下一业务域，建议）
- [ ] FS-3：User 核心
- [ ] FS-4：Admin 非 Moe
- [ ] FS-5：社交与内容
- [ ] FS-6：AI / LLM
- [ ] FS-7：Chat / Voice
- [ ] FS-8：退役 `super.api` / `super.proto`

### 各域域内进度

| 域 | 域内 % | 阶段 |
|----|--------|------|
| Moe | 100% | ✅ |
| VIP | 20% | 试点只读 |
| User | 0% | FS-3 |
| Admin（非 Moe） | 0% | FS-4 |
| 社交 / AI / 实时 / 其它 | 0% | FS-5～7 |

## 日常验收

```bash
cd backend
make verify-moe-complete    # A
make verify-kratos-100      # B + Hybrid 回归
make build-moe-social       # 生产单二进制
make moe-social             # :8888 开发
```
