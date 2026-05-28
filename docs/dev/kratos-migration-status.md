# Kratos 迁移 — 当前进度

> **更新：2026-05-27** · SSOT：[kratos-migration.md](./kratos-migration.md)

## 总览

| 项 | 状态 | 说明 |
|----|------|------|
| 生产入口 | ✅ | `make moe-social` · `config/config.yaml` |
| Kratos HTTP :8888 | ✅ | `api/moehttp` + `routes_*_gen` |
| Kratos gRPC :8080 | ✅ | `kratos_grpc_managed` |
| 业务下沉 biz+GW | ✅ | F 曲线完成 |
| 契约分片 FS-9 | ✅ | `moe.api` / `moe.proto` + `defs/` |
| 验收脚本 | ✅ 已移除 | 用 `make check` + `/migration` |
| 新接口纪律 PK-1 | 🔄 执行中 | 新能力走域 proto，见 [new-api-kratos.md](./new-api-kratos.md) |
| 存量 goctl 退役 | 🔄 渐进 | 247 路由经 `routes_native_gen` 桥接，按域迁 `internal/service` |

## 已完成（无需再跑 verify）

- [x] 单进程 Kratos 生产（PK-8/9）
- [x] `api/moehttp` HTTP 注册（原 moekratospilot）
- [x] `scripts/gen/` 生成链；`make gen` 不覆盖 logic
- [x] `api/internal/logic` 零 `SuperRpcClient`（F110）
- [x] RPC logic 薄层 + `internal/biz`（FS-10）
- [x] 域 proto 试点：moe / vip / admin_insights / llm / ai / chat

## 老接口「实现层」迁移（可开工）

> `/migration` 的 **100%** 指传输/PK 铺轨，**不等于** 247 条路由已脱离 `api/internal/logic`。

| 层级 | 进度 | 说明 |
|------|------|------|
| 传输 Kratos :8888 | **100%** | 268 路由均在 Kratos 注册 |
| 业务 `internal/biz` + `*gw` in_process | **~100%** | logic 内已无 `SuperRpcClient` |
| **HTTP 实现** `internal/service` + `*_compat.go` | **~13%** | **36** 条直挂 service；**227** 条仍 `wrapNativeHTTP`→goctl logic |
| 契约域 proto | **6 个域** | moe / vip / admin_insights / llm / ai / chat |
| goctl logic 文件 | **252** | 待按域收口 |

**建议波次**（每波：域 proto 补全 → `internal/service` → `moehttp` compat → 从 `skipExactPaths` 剔除 → `make gen-http-routes`）：

1. **小域** ✅：`checkin`(7) · `achievement`(4) · `behavior`(1) · `gift`(6) · `comment`(2) — 已迁 `api/moehttp/*_compat.go`
2. **社交读**：post(9) · community(11) — 流量高、service 已有
3. **LLM/AI**：llm(9) 已 2 条 compat，补写/推理路由
4. **User App**：user(51) — 体量大，按子域拆（profile / vip / oauth）
5. **Admin**：admin(86) — 已部分 compat，剩余 CRUD/审核

详见 [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md)。

## 进行中

- [ ] 新接口 **禁止** 扩 `api/defs`（团队纪律）
- [ ] 按域将热点路由从 `logic` 迁到 `internal/service` + `moehttp` compat
- [ ] 文档与 Codex 指南与本文对齐（2026-05-27 批次）

## 已废弃（勿引用）

- `make moe-kratos`、`:19031/:19032` 试点进程
- `make verify-*`、`scripts/verify/`
- `MOE_ALLOW_GOCTL_API` 门禁（已改为 `make gen-api` 直接可用 + 提示）

## 自检

```bash
cd backend
make check
make moe-social
curl -s http://127.0.0.1:8888/migration
curl -s http://127.0.0.1:8888/health
```
