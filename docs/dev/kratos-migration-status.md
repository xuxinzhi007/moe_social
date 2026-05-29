# Kratos 迁移 — 状态板（Current / Next）

> **最后更新：2026-05-29（D4 Phase-2 完成 · 三套口径 100%）**  
> **读这个**：本文 = **当前状态 + 下一步** 快照（汇报 / 勾选用）  
> **架构审计（双轨 / 遗留问题）**：[kratos-architecture-audit.md](./kratos-architecture-audit.md)

| 文档 | 用途 |
|------|------|
| [kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md) | P6 批次、DoD、桥接约定、产物清单 |
| [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) | 存量 compat 历史清单（§2 路由表；**活跃数以本文 D2 表为准**） |
| [kratos-migration.md](./kratos-migration.md) | 架构 SSOT |

---

## 总览（一眼）

| 阶段 | 完成度 | 一句话 |
|------|--------|--------|
| P0–P3 生产 HTTP | **100%** | compat 逻辑已进 service → biz（运行时 Kratos） |
| P4 目录 / 12 gRPC | **~100%** | 独立域 RPC 已注册 |
| P5 Super + 零 go-zero | **100%** | 单进程 Kratos；生产无 go-zero |
| **P6 契约 proto SSOT** | **100%** | service/compat 主域 `*v1`；defs 已 P6 标注 |
| **P0/P1 审计（HTTP 契约 + Admin/User）** | **100%** | 信封统一 · Admin/User/记忆/wave2 已 proto HTTP |
| **D2 compat → proto HTTP** | **100%** | **254** proto · **0** 可迁移 compat（+ **11** intentional） |
| **D4 删遗留层** | **100%** | Phase-0 死代码已删；Phase-2 `biz`/`apilegacy` 零 `rpc/pb/moe` |

> **三套进度口径（勿混用）** — `GET /migration` JSON：
> - `rollout_percent` = P0–P5 传输铺轨（**100%**）
> - `d2_proto_http_pct` = D2 proto HTTP / (proto + 可迁移 compat)（**100%**）
> - `d4_legacy_cleanup_pct` = D4 遗留层清理（**100%**）
> - `percent` = 综合完成度 **(d2×50 + d4×50)/100**（**100%**）

> **易混淆**：P6「契约 100%」≠ D2 完成；`rollout_percent=100` ≠ `percent=100`。

---

## 当前状态（Current）

| 阶段 | 状态 | 说明 |
|------|------|------|
| **P0–P3（生产）** | ✅ **100%** | 运行时 Kratos · api logic 0 · `rollout_percent=100` |
| **P4（理想目录）** | ✅ **~100%** | data 20/21 域 · 独立 gRPC **12/12** |
| **P5-A（Super 运行时）** | ✅ **100%** | 单进程不注册 Super · API 无 zrpc 回环 · AppAdapter |
| **P5-B（logic + 契约）** | ✅ **100%** | `rpc/internal/logic` **0** · `superserver` 已删 |
| **P5-C（gateway Super）** | ✅ **100%** | `api/*gw` 无 `SuperClient` · 分体 dial MoeAdmin |
| **P5-D 生产零 go-zero** | ✅ **100%** | 依赖树与源码无 go-zero；P5-E 已删 hybrid 壳 |

### P5 进度

| 轨道 | 状态 | baseline |
|------|------|----------|
| **P5-A 运行时** | ✅ | `super_grpc_retired` + `single_process` |
| **P5-B rpc logic 清库** | ✅ | **209 → 0** 文件 |
| **P5-C gateway** | ✅ | 23× `*gw` 去 `moe.SuperClient` |
| **P5-D 生产零 go-zero** | ✅ | 默认构建；hybrid 源码已删除（P5-E） |

### 独立 gRPC（12）

`Landing` · `Checkin` · `Achievement` · `PostService` · `GiftService` · `MoeAdmin` · `UserService` · `CommentService` · `Community` · `PrivateMessageService` · `NotifyService` · `VipService`

### 进度百分比（汇报用）

| 目标 | 完成度 |
|------|--------|
| 生产 Kratos（`make moe-social`） | **100%** |
| P5 Super 退役 + 生产零 go-zero | **100%** |
| **P6 契约 defs → 域 proto** | **100%** |
| 仓库删除全部 go-zero 源文件 | **100%**（P5-E：`scripts/archive/p5/p5e-remove-hybrid-gozero.py`） |
| go.mod 无 go-zero | **100%** |
| P6-C `api/defs` 已迁路由标注 | **100%**（`scripts/gen/p6_mark_defs.py`） |
| **P0/P1 审计（架构）** | **100%** | 见 [kratos-architecture-audit.md §4](./kratos-architecture-audit.md) |

### 验收（2026-05-29）

```bash
cd backend && go build ./cmd/moe-social   # ✅ HTTP-only 生产入口
cd backend && go build ./...              # ✅
go test ./internal/platform/moesocial/... ./internal/platform/kratosprogress/... -count=1
go list -deps ./cmd/moe-social | grep go-zero   # P5-D：应无输出
```

> **2026-05-29（完整性清理）**：`backend/rpc/` 已删；部署/Docker/配置统一为单二进制 `moe-social`；死代码（moekratos、SuperRpc dial、双容器 compose）已移除。

---

## P6 — 契约 defs → 域 proto（100%）

> 详表：[kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md)

### 批次勾选

| 批次 | 状态 | 说明 |
|------|------|------|
| 6-0 **behavior** | ✅ | `behavior/v1` · service · compat |
| 6f **social 六域** | ✅ | landing · achievement · checkin · comment · gift · post · community |
| 6f **notify**（gRPC） | ✅ | `notify/v1` · `service/notify`；HTTP 通知列表走 `UserApp` + `userv1` |
| 6g **ai / llm** | ✅ | `ai/v1` · `llm/v1`（含用户记忆 8 路由 HTTP） |
| 6d **admin** | ✅ | `admin/v1` · `AdminApp` + `AdminInsights` proto HTTP |
| 6e **user** | ✅ | `user/v1` · 社交/VIP/OAuth 已 proto HTTP（OAuth 回调 2 条 compat） |
| 6a **wave2 杂项** | ✅ | 大部分迁入 proto；图片 upload 4 条 compat |
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
| service import `rpc/pb/moe` | — | **0**（`FromMoe` 过渡已迁至 biz `adminv1_out` / `proto_v1` / `post` helpers） |
| Moe 工具端口命名 | `pkg/moe/port.MoeToolPort` · `MoeToolGRPCAdapter` · `AttachMoeToolPort` | **已统一**（原 SuperPort） |
| compat 调 App 直传 `&moe.*` | `internal/server/httplegacy/*.go` | **0** |
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
| ~~0~~ | ~~P0/P1 审计项~~ | ✅ 2026-05-27 完成，见 [kratos-architecture-audit.md §4](./kratos-architecture-audit.md) |
| 1 | ~~**D4 Phase-4**：退役 `rpc/pb/moe` 生成链~~ | ✅ 2026-05-29；`common.proto` 归档 · pb 已删 |
| 2 | **intentional transport** 长期方案 | [kratos-intentional-transport.md](./kratos-intentional-transport.md)（media/v1 已迁入 proto） |
| 4 | 生产分体容器化切流 | [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) |

### D2 — HTTP 路由实测（2026-05-29）

| 指标 | 数值 |
|------|------|
| Proto HTTP 路由 | **258** |
| Compat 活跃路由 | **7**（全部为 intentional） |
| 可迁移（D2 债务） | **0** |
| intentional | **7**（OAuth 2 · SSE 1 · WS 4） |
| `d2_proto_http_pct` | **100%** |
| `d4_legacy_cleanup_pct` | **100%** |
| `percent`（综合） | **100%** |

**2026-05-29 goctl 清库：** 删除 `api/defs/*.api`、`rest.swagger.json`、`cmd/dev`；`make gen-api` 退役；默认 `moe.http_only: true`（仅 :8888）

**2026-05-29 目录提纯：** 删除 `httplegacy/`、`api/internal/`、`rpc/pb/moe|super`；OAuth/WS/SSE 迁入 `internal/server/transport/`；proto 路由数由 `make gen` → `gen-proto-route-count` 统计

**2026-05-29 media/v1：** 图片四路由迁入 `api/media/v1` + `mediagrpc`；intentional 降至 7 条

**2026-05-29 D4 Phase-0：** 删除 26 个 zero-route compat/convert 文件；`httplegacy` 无 `rpc/pb/moe` import；仅保留 7 条 intentional compat

**2026-05-29 D4 Phase-4：** 删除 `rpc/pb/moe`/`super` 生成物；`common.proto` → `scripts/archive/rpc-defs/`；HTTP 分层为 `RegisterProtoHTTP` + `RegisterDocsHTTP` + `RegisterIntentionalTransportHTTP`

### 2026-05-27 P0/P1 收口

| 项 | 验收 |
|----|------|
| P0 compat 信封 | `compat_envelope.go` Filter ✅ |
| P1 AdminApp / legacy / readonly | proto HTTP；legacy 仅 SSE 1 条 ✅ |
| P1 User 社交/VIP + 记忆 + wave2 | proto HTTP；OAuth/图片有意保留 compat ✅ |
| 进度口径 | `nativeDomainRouteCount=227` · `PilotNativeCompatRoutes=45` ✅ |
| `go test ./internal/platform/kratosprogress/...` | ✅ |

### 2026-05-27 完成项（信封 / 客户端）

| 项 | 验收 |
|----|------|
| Proto 统一响应信封 | `http_envelope.go` + 单测 ✅ |
| CORS（Flutter Web） | `cors.go` ✅ |
| Flutter `ApiResponse` 全量迁移 | `lib/services/api_response.dart` ✅ |
| 架构审计文档复核 | 本文 + `kratos-architecture-audit.md` ✅ |

### 2026-05-29 历史完成项

| 项 | 验收 |
|----|------|
| P6 platform/vip/defs | `platform_compat` · `vip/admin_rpc` → `adminv1` · `p6_mark_defs.py` |
| gRPC 冒烟 notify/chat/vip | `GRPC_SMOKE=1 go test ./internal/platform/grpcsmoke/...` ✅ |
| 分体联调脚本 | `make split-deploy-smoke` |
| 移除 hybrid go-zero | 删 314 文件 · `go.mod` 无 go-zero · `go build ./...` ✅ |
| **目录提纯** | 去 `!hybrid` 标签 · 重命名 `wrapNetHTTPHandler`/`TotalHTTPRoutes` · 删 p5d 脚本 |
| **service 边界 + MoeToolPort** | `internal/service` 零 `rpc/pb/moe` · `SuperPort`→`MoeToolPort` · `go build ./...` ✅ |
| **Server 命名 S0** | `moekratoshttp` → `internal/server/http.go`（`RegisterOpsHTTP`） |
| **Server S1–S3** | `moegrpc`→`grpc/` · `grpc.go` · `NewHTTPServer` · `http_compat.go` · `cmd/moe-social` 补齐 |
| **D0 proto HTTP** | 18 域 `*_http.pb.go` · `http_proto.go` · **227** 路由 |
| **D1 目录迁出** | `httplegacy/` · `internal/platform/{svc,wiring}` · `internal/apilegacy/` · `internal/legacy/types` |

---

## 自检

```bash
cd backend && go build ./...
make audit-logic-orphans
go list -deps ./cmd/moe-social | grep go-zero
curl -s http://127.0.0.1:8888/migration | jq '.breakdown | {percent, p5: .p5_super_runtime_pct}'
```
