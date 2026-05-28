# Kratos 迁移 — 当前进度

> **更新：2026-05-27** · SSOT：[kratos-migration.md](./kratos-migration.md) · 存量迁移：[kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md)

## 总览

| 项 | 状态 | 说明 |
|----|------|------|
| 生产入口 | ✅ | `make moe-social` · `config/config.yaml` |
| Kratos HTTP :8888 | ✅ | `api/moehttp` · `native_gen=0` · `bridge=2` |
| Kratos gRPC :8080 | ✅ | `kratos_grpc_managed` |
| 业务下沉 biz+GW | ✅ | F 曲线完成 |
| 契约分片 FS-9 | ✅ | `moe.api` / `moe.proto` + `defs/` + **15** 域 `api/*/v1/*.proto` |
| HTTP compat 按域拆分 | ✅ | 见 [compat 清单](./kratos-legacy-api-migration.md#21-apimoehttp-compat-清单263-路由) |
| 验收脚本 | ✅ 已移除 | 用 `make check` + `/migration` |
| 新接口纪律 PK-1 | 🔄 执行中 | [new-api-kratos.md](./new-api-kratos.md) |
| 实现层直挂 App | 🔄 ~21% | **56/263** 条 compat 直挂 `internal/service` |

## 已完成

- [x] 单进程 Kratos 生产（PK-8/9）
- [x] `api/moehttp` HTTP 注册；`routes_native_gen` **归零**
- [x] compat 拆分：`user_*` / `community` / `ai` / `chat` / `wave2_misc` / `platform_compat` / `admin_service` + `admin_legacy`
- [x] 波次 1 小域：checkin · achievement · behavior · gift · comment（直挂 App）
- [x] post · community · gift · comment 域 proto + `*_compat.go` 直挂
- [x] `scripts/gen/` 生成链；`make gen` 不覆盖 logic / `*_compat.go`
- [x] `api/internal/logic` 零 `SuperRpcClient`

## 老接口「实现层」迁移

> `/migration` 的 **100%** 指传输/PK，**不等于** 263 条 compat 均已直挂 `internal/service`。

| 层级 | 进度 | 说明 |
|------|------|------|
| 传输 Kratos :8888 | **100%** | 268 路由均在 Kratos 注册 |
| 业务 `internal/biz` + `*gw` in_process | **100%** | logic 内无 `SuperRpcClient` |
| **HTTP compat 注册** | **100%** | 263 条 `*_compat.go` + 2 bridge |
| **HTTP 直挂 `internal/service`** | **~21%** | 56 条分档 A；107 条 invokeLogic；100 条 wrapNativeHTTP |
| 域 proto（占位/部分 RPC） | **15 域** | 含 `user` · `community` · `post` · `gift` · `comment` 等 |

## 进行中

- [ ] `admin_service_compat` 内联 `AdminApp`（55 条）
- [ ] `user_compat` + `user_memory_compat` → `UserApp` / `LLMApp`（57 条）
- [ ] `ai_compat` · 私信 → `AIApp` / `ChatApp`
- [ ] `platform_compat` LLM 写 → `LLMApp`（复杂 chat 可后置）
- [ ] 新接口 **禁止** 扩 `api/defs`

## 已废弃（勿引用）

- `make moe-kratos`、`:19031/:19032` 试点进程
- `make verify-*`、`scripts/verify/`
- `api/moehttp/user_logic_compat.go`、`wave2_logic_compat.go`、`platform_logic_compat.go`、`admin_logic_compat.go`

## 自检

```bash
cd backend
make check
make moe-social
curl -s http://127.0.0.1:8888/migration
curl -s http://127.0.0.1:8888/health
```
