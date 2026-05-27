# Kratos 迁移 — 进度清单

> **纯 Kratos 方案：100%** · **Hybrid Moe：100%** · **对外 HTTP：:8888 不变**  
> 验收：`make verify-kratos-100`

## Hybrid Moe ✅

- [x] `make verify-moe-complete` / `make moe-social` → **:8888**

## 纯 Kratos 方案 ✅ 100%

- [x] Phase 0～4
- [x] Phase 5：VIP 只读 `internal/biz/vip`
- [x] Phase 6：`make build-moe-social` 生产单二进制

## 验收

```bash
cd backend
make verify-kratos-100
make build-moe-social
```
