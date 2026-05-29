# Kratos 迁移 — 状态板（Current / Next）

> **最后更新：2026-05-29**  
> **读这个**：本文 = **当前状态 + 下一步** 快照（汇报 / 勾选用）

| 文档 | 用途 |
|------|------|
| [kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md) | P6 批次、DoD、桥接约定、产物清单 |
| [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) | P3 路由 263、compat 注册锚点 |
| [kratos-migration.md](./kratos-migration.md) | 架构 SSOT |

---

## 总览（一眼）

| 阶段 | 完成度 | 一句话 |
|------|--------|--------|
| P0–P3 生产 HTTP | **100%** | 263 compat → service → biz |
| P4 目录 / 12 gRPC | **~100%** | 独立域 RPC 已注册 |
| P5 Super + 零 go-zero | **100%** | 单进程 Kratos；生产无 go-zero |
| **P6 契约 proto SSOT** | **100%** | service/compat 主域 `*v1`；defs 已 P6 标注 |

---

## 当前状态（Current）

| 阶段 | 状态 | 说明 |
|------|------|------|
| **P0–P3（生产）** | ✅ **100%** | compat 263 · api logic 0 · `/migration percent=100` |
| **P4（理想目录）** | ✅ **~100%** | data 20/21 域 · 独立 gRPC **12/12** |
| **P5-A（Super 运行时）** | ✅ **100%** | 单进程不注册 Super · API 无 zrpc 回环 · AppAdapter |
| **P5-B（logic + 契约）** | ✅ **100%** | `rpc/internal/logic` **0** · `superserver` 已删 |
| **P5-C（gateway Super）** | ✅ **100%** | `api/*gw` 无 `SuperClient` · 分体 dial MoeAdmin |
| **P5-D（零 go-zero 生产）** | ✅ **100%** | `go list -deps ./cmd/moe-social` 无 `go-zero` |

### P5 进度

| 轨道 | 状态 | baseline |
|------|------|----------|
| **P5-A 运行时** | ✅ | `super_grpc_retired` + `single_process` |
| **P5-B rpc logic 清库** | ✅ | **209 → 0** 文件 |
| **P5-C gateway** | ✅ | 23× `*gw` 去 `moe.SuperClient` |
| **P5-D 生产零 go-zero** | ✅ | 默认构建；legacy 在 `//go:build hybrid` |

### 独立 gRPC（12）

`Landing` · `Checkin` · `Achievement` · `PostService` · `GiftService` · `MoeAdmin` · `UserService` · `CommentService` · `Community` · `PrivateMessageService` · `NotifyService` · `VipService`

### 进度百分比（汇报用）

| 目标 | 完成度 |
|------|--------|
| 生产 Kratos（`make moe-social`） | **100%** |
| P5 Super 退役 + 生产零 go-zero | **100%** |
| **P6 契约 defs → 域 proto** | **100%** |
| 仓库删除全部 go-zero 源文件 | **100%**（P5-E：`p5e-remove-hybrid-gozero.py`） |
| go.mod 无 go-zero | **100%** |
| P6-C `api/defs` 已迁路由标注 | **100%**（`scripts/gen/p6_mark_defs.py`） |

### 验收（2026-05-27）

```bash
cd backend && go build ./api ./rpc ./cmd/moe-social   # ✅
cd backend && go build ./...                        # ✅
go test ./internal/platform/kratosprogress/... -count=1
go list -deps ./cmd/moe-social | grep go-zero          # P5-D：应无输出
```

---

## P6 — 契约 defs → 域 proto（100%）

> 详表：[kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md)

### 批次勾选

| 批次 | 状态 | 说明 |
|------|------|------|
| 6-0 **behavior** | ✅ | `behavior/v1` · service · compat |
| 6f **social 六域** | ✅ | landing · achievement · checkin · comment · gift · post · community |
| 6f **notify**（gRPC） | ✅ | `notify/v1` · `service/notify`；HTTP 通知列表走 `UserApp` + `userv1` |
| 6g **ai / llm** | ✅ | `ai/v1` · `llm/v1` · `ai_compat` · `user_memory_compat` |
| 6d **admin** | ✅ | `admin/v1` messages · service · `admin_*_compat` · `admingw` bridge |
| 6e **user** | ✅ | `user/v1` messages · `user_compat` · `user_convert` |
| 6a **wave2 杂项** | ✅ | `wave2_misc_compat`（admin 登录/bootstrap · 头像 · 站内通知） |
| 6h **chat** | ✅ | `chat/v1` · service · chatgw |
| 6b **vip** | ✅ | 用户侧 `vipv1`；`vip/admin_rpc` → `adminv1` |
| 6a **platform** | ✅ | `platform_compat` → `MoeAdmin`/`UserApp` + `userv1` |
| 6c **moe App** | ✅ | `MoeAdmin.ExecuteTool`（biz 输入，无 GW `moe.*`） |
| **P6-C** defs | ✅ | 10 个 `api/defs/*.api` 文件头 + 逐路由 `P6 migrated` 注释 |

### 产物清单（仓库内可核对）

| 类型 | 路径模式 | 数量 / 域 |
|------|----------|-----------|
| 大域 message + 生成 bridge | `api/{admin,user,ai,llm,vip}/v1/*_messages.proto` · `moe_bridge_gen.go` | **5** |
| 社交/平台 hand bridge | `api/{behavior,landing,…,chat,notify}/v1/moe_bridge.go` | **10** |
| service 已用 `*v1` 签名 | `internal/service/{behavior,landing,…,notify,ai,llm,admin,user,chat,post,vip,…}` | **主域已覆盖** |
| service 仍 import `moe`（边界构造） | `admin/app.go` · `user/app.go` · `post/app.go` · `notify/app.go` | **4**（`FromMoe`/`ToMoe` 过渡，非直挂 RPC） |
| compat 调 App 直传 `&moe.*` | `api/moehttp/*.go` | **0** |
| 生成脚本 | `backend/scripts/gen/p6_*.py` | extract · migrate · wrap · `p6_mark_defs.py` |

### 2026-05-27 收口记录

- `platform_compat.go` — `MoeAdmin.ExecuteTool` · `UserApp.GetUser` + `userv1`（移除 GW `&moe.*`）  
- `vip/admin_rpc.go` · `biz/vip/proto.go` — 管理端 VIP CRUD → `adminv1`  
- `admin_service_compat.go` — VIP 四路由 `adminv1` + `AdminVipPlanToTypes`  
- `api/defs/*.api` — P6-C 文件头 + 逐路由 SSOT 注释（`p6_mark_defs.py`）  
- 历史：`user_compat` · `checkin_compat` · `user_memory_compat` · `wave2_misc_compat`（`FromMoe` bridge）

运行时 P3/P5 **不重复**；P6 只换契约类型来源，**不改** HTTP 路径与 JSON 字段名。

---

## 下一步（Next）

| 优先级 | 任务 | 文档 |
|--------|------|------|
| — | ~~P6 / grpc 冒烟 / 分体联调 / 移除 hybrid go-zero~~ ✅ | 见下表 |
| 1 | 生产分体容器化切流 | [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) |
| 2 | 可选：清理 `rpc/pb/moe` 边界 `FromMoe` | [kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md) |

### 2026-05-29 完成项

| 项 | 验收 |
|----|------|
| P6 platform/vip/defs | `platform_compat` · `vip/admin_rpc` → `adminv1` · `p6_mark_defs.py` |
| gRPC 冒烟 notify/chat/vip | `GRPC_SMOKE=1 go test ./internal/platform/grpcsmoke/...` ✅ |
| 分体联调脚本 | `make split-deploy-smoke` |
| 移除 hybrid go-zero | 删 314 文件 · `go.mod` 无 go-zero · `go build ./...` ✅ |

---

## 自检

```bash
cd backend && go build ./...
make audit-logic-orphans
go list -deps ./cmd/moe-social | grep go-zero
curl -s http://127.0.0.1:8888/migration | jq '.breakdown | {percent, p5: .p5_super_runtime_pct}'
```
