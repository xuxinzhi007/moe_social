# Kratos 迁移历史（归档）

> **归档说明**：Kratos 迁移已全部完成。compat / httplegacy / `api/defs` / `internal/apilegacy` / `rpc/pb/moe` 桥 / `/migration` 进度端点均已删除，**全部路由均为 proto 路由**。
> **当前架构与新接口开发只看**：[new-api-kratos.md](./new-api-kratos.md)；过渡层删除记录见 [cleanup-2026-10-15.md](./cleanup-2026-10-15.md)；仓库目录见 [backend/LAYOUT.md](../../backend/LAYOUT.md)。
> 本文合并自以下七篇历史文档（原文件已删除）：`kratos-migration.md`、`kratos-migration-status.md`、`kratos-architecture-audit.md`、`kratos-directory-ssot.md`、`kratos-legacy-api-migration.md`、`kratos-server-layout-migration.md`、`kratos-p6-defs-to-proto.md`。
> ⚠️ 文中所有路由条数（227 / 45 / 263 等）、进度百分比、目录与文件快照均为**迁移期历史口径**；与现状冲突处以代码现状 / new-api-kratos.md 为准。

---

## 1. 迁移总览

后端从 **go-zero 多进程（api + rpc + Super gateway）** 迁移到 **Kratos 单进程 HTTP-only**（`cmd/moe-social`，`:8888`），契约 SSOT 从 goctl 的 `api/defs/*.api` 切换到 `api/<domain>/v1/*.proto` + `google.api.http` 注解。

### 1.1 阶段代号对照

| 代号 | 含义 | 来源文档 |
|------|------|----------|
| P0 | 双轨 HTTP 契约统一：proto 响应信封 + compat 信封压平 + Flutter 双格式解析 | audit |
| P1 | Admin / User 社交·VIP / 用户记忆 / wave2 大批量 compat → proto HTTP | audit |
| P2 | platform / LLM 只读 / 社交余量 compat；WebSocket、SSE、OAuth 回调、multipart 例外 | audit |
| P3 | 263 条 goctl 路由全部挂到 Kratos compat，直调 `internal/service` → `biz`；`api/internal/logic` 清库 | legacy-api |
| P5 | Super gateway 退役；`rpc/internal/logic` 清库；生产依赖树零 go-zero（P5-D） | legacy-api |
| P6 | 契约 SSOT 迁到域 proto：message 抽出、`FromMoe/ToMoe` 桥、`api/defs` 标注归档（P6-C） | p6 |
| D0 | HTTP 生成链打通：`third_party/google/api` + `protoc-gen-go-http` → `*_http.pb.go` | directory-ssot |
| D1 | `api/` 瘦身：`moehttp`→`httplegacy`、`runserver`→`platform/wiring`、`svc/gw/types` 各归其位 | directory-ssot |
| D2 | compat → proto HTTP 退役（263 → 45 → 11 → 0） | directory-ssot |
| D3 | 清空 `api/internal` | directory-ssot |
| D4 | 删 `httplegacy` 死代码、`apilegacy/*gw`、`moe_bridge`、`rpc/pb/moe` 引用归零 | directory-ssot |
| S0–S5 | `internal/server` 目录命名与装配收敛（对齐 Kratos 官方 / core-platform） | server-layout |

### 1.2 关键时间线

| 日期 | 事件 |
|------|------|
| 2026-05-27 | P0/P1 收口：proto 227 条 + compat 45 条；`/migration percent=100`（历史口径） |
| 2026-05-29 | 宣布迁移完成（HTTP-only）；D4 Phase-0/2/3：`moe_bridge*.go`、域 `grpc/*/convert.go` 删除，`rpc/pb/moe` 运行时引用归零 |
| 2026-07-09 | 进度追踪与 `/migration` 端点移除，状态板停止更新 |
| 2026-09-08 | `make gen-api` / `make gen-rpc` / `make gen-http-routes` 等 goctl 系 target 从 Makefile 删除 |
| 2026-09 起 | compat / httplegacy 过渡层整体删除，全部路由均为 proto 路由（见 new-api-kratos.md） |
| 2026-10-15 | 过渡层清理记录归档（cleanup-2026-10-15.md） |

---

## 2. 迁移完成时的架构快照（2026-05-29，历史）

> 来源：`kratos-migration.md`。以下为迁移刚完成时的架构描述；`internal/platform` 包清单等细节此后仍有变动，**当前目录以 new-api-kratos.md §1 为准**。

```text
Client (:8888)
      │
      ▼
cmd/moe-social → internal/platform/moesocial
      │
      ▼
internal/server/http.go
  ├─ RegisterProtoHTTP  → internal/server/protohttp/<domain>/
  ├─ RegisterTransportHTTP → OAuth / WS / SSE
  └─ RegisterDocsHTTP → /swagger

protohttp/<domain> → internal/service → internal/biz → internal/data
```

| 路径 | 角色 |
|------|------|
| `cmd/moe-social/` | 生产入口 |
| `config/config.yaml` | 配置 SSOT |
| `api/<domain>/v1/*.proto` | 契约 SSOT |
| `openapi.yaml` | `make gen` 产出 |
| `internal/server/protohttp/` | proto HTTP 适配层 |
| `internal/server/swaggerdoc/` | Swagger UI |
| `internal/biz/moe/moebridge/` | Moe proto↔biz 转换 |

---

## 3. 架构审计结论（2026-05-27 快照，历史）

> 来源：`kratos-architecture-audit.md`。当时结论：「生产运行时已是纯 Kratos 单进程（无 go-zero），官方 HTTP 生成链已打通；P0/P1 已 100% 收口，compat 余量约 45 条，D4 全删 `httplegacy` 待 D2 完成后进行。」——D2/D4 此后已全部完成，compat 余量现为 **0**。

### 3.1 当时的路由分布（历史口径）

| 来源 | 条数 | 说明 |
|------|------|------|
| Proto HTTP | 227 | 18 域 `Register*HTTPServer` |
| Compat 活跃 | 45 | P2 平台域 17 · community/chat/ai/checkin 19 · OAuth 回调 2 · LLM 只读 2 · SSE 1 · multipart 4 |
| Bridge | 3 | `/swagger` 三件套 |

当时的完成度矩阵要点：单进程 Kratos ✅、官方 proto HTTP 链 ✅、统一响应信封 ✅（P0）、CORS ✅、Flutter 双格式解析 ✅；`httplegacy` 删除、`rpc/pb/moe` 与 `apilegacy` 零引用当时 ❌，**现均已完成**。

### 3.2 响应格式设计（部分仍然有效）

> 来源：audit §5。proto 信封与 Flutter 解析**至今有效**（细节以 new-api-kratos.md §7 为准：proto 字段嵌在 `data` 里）；compat 压平一段**已过时**，随 compat 层一并删除。

- **Proto HTTP 信封**：`internal/server/http_envelope.go` 全局挂载，成功 `{code, success, message, data:{...}}`，错误带 `reason`。
- **Compat 压平（已删除）**：当时经 `compat_envelope.go` Filter 把 `BaseResp.data` 压平到顶层，使 compat 与 proto 对外同形。
- **Flutter 解析 SSOT**：`lib/services/api_response.dart`（`listOf` / `object` / `authSession` / `isSuccess`），为兼容双格式而设计，现兼容历史 `data` 嵌套。

### 3.3 当时遗留问题与最终解法

| 当时问题（P2–P4） | 最终解法 |
|-------------------|----------|
| `apilegacy/*gw` 伪 gRPC 网关、`FromMoe/ToMoe` 类型双份 | compat 退役时同步删除；biz 只认 `api/<domain>/v1` 类型 |
| biz 层 import `rpc/pb/moe` | D4 Phase-2 归零；`MoeToolPort` / `pkg/moe` 直用域 `*v1` |
| `make gen-api`（goctl）可能覆盖 handler | target 已删；契约生成只走 `make gen` |
| WebSocket 不走 `google.api.http` | 独立 transport：`internal/server/transport/`（ws / sse / oauth / bind） |
| 图片 upload multipart | 同上，走 transport 而非 proto 注解 |
| `/migration` 进度端点与路由计数常量 | 迁移完成后整体移除；路由集合改为枚举装配后的 server，不从 `.pb.go` 推断 |

---

## 4. 目录与 Server 层收敛决策（历史）

> 来源：`kratos-directory-ssot.md` + `kratos-server-layout-migration.md`。决策本身（对齐 Kratos 官方布局）至今有效；文中 compat 条数、`make gen-api`、hybrid 构建桩等均已过时。

### 4.1 对齐目标

以 [Kratos 官方项目布局](https://go-kratos.dev/zh-cn/docs/intro/layout/) 与本机 core-platform 参考实现为锚：`internal/server` 只保留 `http.go` / `grpc.go` 装配入口，路由来自 proto 生成的 `RegisterXxxHTTPServer`；无 `api/internal`、无 compat、无 `*gw`。

### 4.2 命名与搬迁记录（S0–S2）

| 原位置 | 迁到 | 备注 |
|--------|------|------|
| `internal/server/moekratoshttp/` | `internal/server/http.go`（`RegisterOpsHTTP`） | 运维路由 |
| `internal/server/moegrpc/` | `internal/server/grpc/` | 后随 HTTP-only 化删除 |
| `api/moehttp/*_compat.go` | `internal/server/httplegacy/` | 后于 D4 整体删除 |
| `api/runserver/` | `internal/platform/wiring/` | |
| `api/internal/{svc,gw,common,…}` | `internal/platform/svc` + `internal/apilegacy/` | 后者后于 D4 删除 |
| `api/internal/types` | `internal/legacy/types` | 仅存旧结构体，无路由 |
| `api/defs/` | 只读镜像 `scripts/archive/api-defs/` | 后随 proto SSOT 确立整体删除 |

### 4.3 `api/internal` 收敛去向（决策记录）

| 子目录 | 去向 |
|--------|------|
| `types/` | 随 compat 删除；新接口用 proto JSON |
| `*gw/` | 删除；由 `chatdelivery` + in-process gateway 替代 |
| `common/*_convert` | `httplegacy/*_convert.go` / `internal/pkg/httputil` |
| `common/error_*` | `internal/pkg/httperr` |
| `svc/` | 并入 `internal/platform/moewiring` |

### 4.4 D1–D4 清单摘要

- **D0** ✅：`third_party/google/api/` + `protoc-gen-go-http`，18 域 `*_http.pb.go`，`http_proto.go` 19 处 `Register*HTTPServer`。
- **D1** ✅：`api/` 瘦身（见 §4.2），`api/defs` 建只读镜像。
- **D2** ✅：compat 263 → 45（P0/P1 后）→ 11（仅 OAuth/SSE/WS/multipart intentional）→ 0（transport 化后）。
- **D3** ✅：`api/internal` 清空（handler stub 随 hybrid 构建标签退役删除）。
- **D4** ✅：删 26 个零路由 compat 文件（~4.7k LOC）、15 个 `apilegacy/*gw` 包、`api/*/v1/moe_bridge*.go`、域 `grpc/*/convert.go`；`make moe-social` 不再链接 `rpc/pb/moe`。

### 4.5 迁移期新接口纪律（已被 new-api-kratos.md 取代）

当时约定：❌ 新路由进 `api/defs` / `httplegacy` / `make gen-api`；✅ `api/<domain>/v1/*.proto` + `google.api.http` + `make gen` + `Register*HTTPServer`。此纪律延续至今，现行版见 new-api-kratos.md §3–§4。

---

## 5. 存量接口迁移（P3 基线，历史）

> 来源：`kratos-legacy-api-migration.md`。数字均为历史口径。

### 5.1 基线与口径

迁移起点为 **268 条 goctl 路由**：`routes_native_gen` 0 · `*_compat` 263 · swagger bridge 2。compat 按域拆为 21 个 `*_compat.go`（admin 系列 98、user 49、wave2 27、platform 17、ai 14、chat 9、post 9、checkin 7 等），全部直挂 `internal/service/*App` → `internal/biz`，不经 `api/internal/logic`。

当时强调「三套进度不要混」：

| 口径 | 含义 |
|------|------|
| `/migration` → `percent` | 传输 + biz/GW + 路由挂 Kratos + logic 清库 |
| `rollout_percent` | 传输铺轨 |
| 生产零 go-zero | `go list -deps ./cmd/moe-social` 无 `zeromicro/go-zero`（不等于仓库删光 go-zero 源文件） |

### 5.2 单域迁移步骤（当时模板）

以 checkin 为例：补全域 proto → `make gen` → `internal/service/<domain>` 暴露方法 → 写 `*_compat.go` 注册 → `make gen-http-routes` 确认 `native=0` → `make check` + 手测 → 无引用后删 `api/internal/logic/<group>`（勿先删 defs）。

### 5.3 当时纪律

- 每域一个 PR，避免与 `make gen-api` 大范围冲突。
- 路径、JSON 字段与现网完全一致（Flutter / moe-admin 无感）。
- 迁移期间不在 `api/defs` 扩新能力。

---

## 6. P6：契约 SSOT 迁到域 proto（历史）

> 来源：`kratos-p6-defs-to-proto.md`。P6 = 100%（2026-05-27）；文中 `moe_bridge` 桥接层后于 D4 全部删除，**仅作历史参考**。

### 6.1 做法

把 message 从 goctl `api/defs/*.api` 抽到 `api/<domain>/v1/*_messages.proto`，service 签名改用 `*v1` 类型；compat 过渡期通过 `*v1.XFromMoe(&moe.X{...})` 做 types → moe → 域 v1 的桥接，或直接构造域 v1 请求。

```go
// 历史示例（桥接代码已删除）
rpcResp, err := app.Login(ctx, userv1.LoginReqFromMoe(&moe.LoginReq{
    Email: req.Email, Password: req.Password,
}))
```

### 6.2 批次记录

| 批次 | 域 | 产物 |
|------|-----|------|
| 6-0 / 6f | behavior · landing · achievement · checkin · comment · gift · post · community · notify | 各 `*/v1` + 手写 `moe_bridge.go`（共 10 套） |
| 6g | ai · llm | `ai/v1` · `llm/v1` + `moe_bridge_gen.go` |
| 6d / 6e / 6b | admin · user · vip | `*_messages.proto` + 生成 bridge（共 5 套，含 admin/user/ai/llm/vip） |
| 6h | chat | `chat/v1` + `moe_bridge.go` |
| 6a / 6c | wave2 杂项 · platform · moe App | admin/user bridge · biz `ExecuteToolInput` |
| P6-C | `api/defs/*.api` | `scripts/gen/p6_mark_defs.py` 批量标注 `P6 migrated`（10/10 文件） |

大域 bridge 为生成物（`moe_bridge_gen.go`），社交/平台域为手写（`moe_bridge.go`）；`internal/service` 中残留的 `rpc/pb/moe` import 仅用于边界包装，最终在 D4 Phase-2/3 归零。

---

## 7. 相关文档

- [new-api-kratos.md](./new-api-kratos.md) — **当前路由架构 SSOT**（新接口开发只看这篇）
- [cleanup-2026-10-15.md](./cleanup-2026-10-15.md) — compat / httplegacy 过渡层删除记录
- [openapi-apifox.md](./openapi-apifox.md) — OpenAPI / Apifox 导入
- [backend/LAYOUT.md](../../backend/LAYOUT.md) — 仓库目录
