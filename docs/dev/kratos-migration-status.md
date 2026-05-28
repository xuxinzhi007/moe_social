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
| **P6 契约 proto SSOT** | **~80%** | service/compat 主域已 `*v1`；defs 未删 |

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
| **P6 契约 defs → 域 proto** | **~80%** |
| 仓库删除全部 go-zero 源文件 | **未做**（hybrid 回滚保留） |
| P6-C 从 `api/defs` 删除已迁路由 | **0%** |

### 验收（2026-05-29）

```bash
cd backend && go build ./api ./rpc ./cmd/moe-social   # ✅
cd backend && go build ./...                        # ✅
go test ./internal/platform/kratosprogress/... -count=1
go list -deps ./cmd/moe-social | grep go-zero          # P5-D：应无输出
```

---

## P6 — 契约 defs → 域 proto（~80%）

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
| 6b **vip** | 🟡 | 用户侧 `vipv1` 已接；`vip/admin_rpc.go` 仍引 `moe` |
| 6a **platform** | 🟡 | `platform_compat` 仍 `MoeGW`/`UserGW` + `&moe.*`（GW 内可 bridge） |
| 6c **moe App** | ⬜ | `moe/v1` · tool 执行等 |
| **P6-C** defs | ⬜ | 未加注释 / 未删路由 |

### 产物清单（仓库内可核对）

| 类型 | 路径模式 | 数量 / 域 |
|------|----------|-----------|
| 大域 message + 生成 bridge | `api/{admin,user,ai,llm,vip}/v1/*_messages.proto` · `moe_bridge_gen.go` | **5** |
| 社交/平台 hand bridge | `api/{behavior,landing,…,chat,notify}/v1/moe_bridge.go` | **10** |
| service 已用 `*v1` 签名 | `internal/service/{behavior,landing,…,notify,ai,llm,admin,user,chat,post,…}` | **主域已覆盖** |
| service 仍 import `moe`（边界构造） | `admin/app.go` · `user/app.go` · `post/app.go` · `notify/app.go` · `vip/admin_rpc.go` | **5**（`FromMoe`/`ToMoe` 过渡，非直挂 RPC） |
| compat 调 App 直传 `&moe.*` | `api/moehttp/*.go` | **0**（2026-05-29） |
| 生成脚本 | `backend/scripts/gen/p6_*.py` | extract · migrate · wrap gw/compat |

### 2026-05-29 收口记录

- `user_compat.go` — 全量 `userv1`/`vipv1` FromMoe + `userFromUserV1` 等 convert  
- `checkin_compat.go` — admin 签到奖励 `adminv1` bridge  
- `user_memory_compat.go` — `llmv1` bridge  
- `wave2_misc_compat.go` — admin 公共登录、头像、站内通知 `adminv1`/`userv1`  

运行时 P3/P5 **不重复**；P6 只换契约类型来源，**不改** HTTP 路径与 JSON 字段名。

---

## 下一步（Next）

| 优先级 | 任务 | 文档 |
|--------|------|------|
| **0** | P6：`platform_compat` GW · `vip/admin_rpc` · defs P6-C | [kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md) |
| 1 | grpc 冒烟 notify / chat / vip | [grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md) |
| 2 | 分体 api/rpc 联调 | [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) |
| 3 | 可选：移除 go-zero | [kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) |

---

## 自检

```bash
cd backend && go build ./...
make audit-logic-orphans
go list -deps ./cmd/moe-social | grep go-zero
curl -s http://127.0.0.1:8888/migration | jq '.breakdown | {percent, p5: .p5_super_runtime_pct}'
```
