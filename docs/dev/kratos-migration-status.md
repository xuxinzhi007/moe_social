# Kratos 迁移 — 进度清单

> SSOT：[kratos-migration.md](./kratos-migration.md)  
> **Moe 域：100%** | **全仓纯 Kratos：进行中（~30% 非 Moe 域待迁）**

## Moe 域（100%）✅

- [x] Phase 1+2 分层 + rpcsuper
- [x] `api_in_process` + `MoeGW`
- [x] `moe.proto` + `moegrpc` + `register_moe_grpc`
- [x] `cmd/moe-social` 单进程
- [x] `make verify-moe-complete`

## 全仓后续 ⬜

- [ ] User / VIP 等域 proto 拆分
- [ ] 退役 `super.api` / `super.proto` 全量 HTTP/RPC
- [ ] 纯 Kratos HTTP 注解 / grpc-gateway

## 验收

```bash
cd backend && make verify-moe-complete
make moe-social
```
