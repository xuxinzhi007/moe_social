# Kratos 迁移 — 进度清单

> **架构说明（框架 / 用法 / 优缺点 / 是否纯 Kratos）**：[kratos-migration.md](./kratos-migration.md)

## Moe 域 Hybrid ✅ 100%

- [x] biz / service / data
- [x] `moe.proto` + `moegrpc` + `MoeGW`
- [x] `cmd/moe-social` 单进程开发入口
- [x] `make verify-moe-complete`

## 全仓纯 Kratos ⬜ 未启动（可选）

- [ ] Moe Admin HTTP → grpc-gateway 试点
- [ ] 非 Moe 域 biz 下沉
- [ ] 退役 `super.api` / `super.proto`
- [ ] 部署默认单二进制

## 验收

```bash
cd backend && make verify-moe-complete && make moe-social
```
