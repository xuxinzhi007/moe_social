# Kratos 架构整理 — 结论与现存问题

> **归档（勿当现状）**：本文反映 2026-05-27 迁移收尾快照；compat / httplegacy / rpc 等描述已过期。  
> **现行 SSOT**：[kratos-migration.md](./kratos-migration.md) · [backend/LAYOUT.md](../../backend/LAYOUT.md) · [kratos-migration-status.md](./kratos-migration-status.md)  
> **日期：2026-05-27（P0/P1 收口）**  
> **范围**：`backend/` 从 go-zero 单栈迁移到 Kratos 官方布局的收尾审计  
> **关联**：[kratos-directory-ssot.md](./kratos-directory-ssot.md) · [kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 结论（一句话）

**生产运行时已是纯 Kratos 单进程（无 go-zero），官方 HTTP 生成链已打通；P0/P1 已 100% 收口，compat 余量约 45 条（多为 P2 平台域 + OAuth 回调 + SSE/静态资源），D4 全删 `httplegacy` 仍待 D2 全量完成后进行。**

| 层次 | 是否「全新架构」 | 说明 |
|------|------------------|------|
| 进程 / 框架 | ✅ 是 | `make moe-social` → Kratos HTTP + gRPC |
| 契约 SSOT（P6） | ✅ 是 | 18 域 `api/<domain>/v1/*.proto` |
| HTTP 路由 | 🟡 **双轨（余量小）** | **227** proto + **45** compat + 3 bridge |
| 响应 JSON | ✅ **P0 已统一** | proto 信封 + `compatEnvelopeFilter` 压平 compat `data` |
| 遗留代码 | ❌ 未清 | `httplegacy/` 瘦身中；`apilegacy/`、`rpc/pb/moe` 仍引用 |

---

## 2. 目标架构 vs 当前状态

### 2.1 官方 Kratos HTTP 链（已对齐）

```text
api/<domain>/v1/*.proto
  + google.api.http 注解
    → make gen → *_http.pb.go
      → internal/server/http_proto.go
        → Register*HTTPServer（生成代码）
          → internal/server/protohttp/<domain>/（薄适配）
            → internal/service → internal/biz → internal/data
```

### 2.2 过渡期旁路（仍在，但逐域缩短）

```text
internal/server/http_compat.go
  → internal/server/httplegacy/*_compat.go
    → internal/apilegacy/*gw（部分路径）
      → internal/legacy/types（BaseResp JSON）
        → internal/service → biz
```

### 2.3 完成度矩阵（2026-05-27 P0/P1 收口）

| 维度 | 状态 | 说明 |
|------|------|------|
| 生产单进程 Kratos | ✅ 100% | `make moe-social`；无 go-zero 运行时 |
| 官方 proto HTTP 链 | ✅ 已打通 | `third_party` + `protoc-gen-go-http` + `http_proto.go` |
| Proto HTTP 路由 | ✅ **227 条** | 18 个 `Register*HTTPServer`（含 content、vipplans 等） |
| 目录 D1 迁移 | ✅ ~95% | `moehttp`→`httplegacy`，`api/internal` 仅 stub |
| Compat 路由退役 D2 | 🟡 **~83%** | **45** 条活跃 compat（原 198）；`PilotNativeCompatRoutes` 与实测一致 |
| 统一响应信封 | ✅ **100%（P0）** | `http_envelope.go` + `compat_envelope.go` Filter |
| CORS（Flutter Web） | ✅ | `internal/server/cors.go` + `khttp.Filter` |
| Flutter 客户端解析 | ✅ | `lib/services/api_response.dart` 双格式桥接 |
| **P0 审计项** | ✅ **100%** | 重复路由已删；JSON 形状 middleware 统一 |
| **P1 审计项** | ✅ **100%** | Admin/User/记忆/wave2 已 proto HTTP（见 §4） |
| `api/defs` 归档 D3 | 🟡 镜像已建 | 活跃 defs 仍服务 `make gen-api` |
| `httplegacy` 删除 D4 | ❌ 未开始 | 45 条 intentional compat 仍注册 |
| `rpc/pb/moe` 零引用 | ❌ 未达成 | compat 死代码与 biz 桥仍引用 |
| `internal/apilegacy` 零引用 | ❌ 未达成 | swagger bridge 等仍装配 |

### 2.4 HTTP 路由实测分布

| 来源 | 条数 | 文件/注册点 |
|------|------|-------------|
| Proto HTTP | **227** | `api/**/*_http.pb.go` → `RegisterProtoHTTP` |
| Compat 活跃 | **45** | `httplegacy/*_compat.go` |
| Bridge | **3** | `/swagger`、`/swagger/openapi.yaml`、`/swagger/doc.json` |
| Ops | **3** | `/health`、`/migration`、`/kratos/v1/moe/runtimes` |
| **合计（去重前）** | **~278** | proto 先注册，compat 后注册 |

**Compat 活跃路由（2026-05-27）：**

| 文件 | 条数 | 说明 |
|------|------|------|
| `platform_compat.go` | 17 | P2 平台域 |
| `community_compat.go` | 7 | 待 D2 |
| `chat_compat.go` | 6 | 待 D2 |
| `wave2_misc_compat.go` | 4 | 图片 upload/静态（multipart） |
| `ai_compat.go` | 4 | 待 D2 |
| `user_compat.go` | 2 | OAuth 回调（重定向） |
| `llm_read_compat.go` | 2 | P2 LLM 只读 |
| `checkin_compat.go` | 2 | 待 D2 |
| `admin_legacy_compat.go` | 1 | SSE `brain/pipeline/stream` |

**已 no-op 的 `Register*Compat`：** AdminApp、AdminInsights、AdminReadonly、UserMemory、AdminService、Vip、Landing、Achievement、Behavior、Gift、Comment、Post、NativeDomain 等。

---

## 3. 本轮收尾已完成项

| 项 | 动作 |
|----|------|
| **P0 compat 信封** | `compat_envelope.go` Filter：压平 `BaseResp.data` → 与 proto 信封同形 |
| **P0 重复路由** | 删除 `admin_legacy` 中与 `moe.proto` 重复的 tools stats/calls |
| **P1 AdminApp** | 55 条 `admin_service_compat` → `AdminApp` proto HTTP + `grpc/adminapp` |
| **P1 Admin legacy** | 28 条 → `AdminApp` / `AdminInsights` / `MoeAdmin`（保留 1 条 SSE） |
| **P1 User 社交/VIP** | 40 条 → `UserService` + `VipService` proto HTTP（保留 2 条 OAuth 回调） |
| **P1 用户记忆** | 8 条 → `LlmChat` proto HTTP |
| **P1 wave2** | 19 条 → Admin/User/Content/Chat/VipPlans proto（保留 4 条图片静态） |
| AdminInsights proto HTTP | `admin_messages.proto` 5 条 + dashboard/growth/schema |
| 统一响应信封 | `http_envelope.go`：proto 成功/错误信封 |
| CORS | `cors.go` + `http.go` Filter（Flutter Web 跨域） |
| Flutter 客户端 | `api_response.dart` 统一解析 |
| 进度口径 | `nativeDomainRouteCount=227`；`PilotNativeCompatRoutes=45` |
| 构建验收 | `go build ./...` + `go test ./internal/platform/kratosprogress/...` ✅ |

---

## 4. 当前存在的问题（按优先级）

### P0 — 双轨 HTTP 契约 ✅ **100%**

| 问题 | 状态 |
|------|------|
| 响应 JSON 形状不一致 | ✅ `compatEnvelopeFilter` 压平 compat 响应 |
| 同路径重复注册 | ✅ moe tools stats/calls 已从 compat 删除 |
| 信封仅覆盖 proto | ✅ compat 经 Filter 后对外同形 |

### P1 — Admin 域 ✅ **100%**

| 模块 | compat 余量 | 状态 |
|------|-------------|------|
| `admin_service_compat` | **0** | ✅ `RegisterAdminAppHTTPServer` |
| `admin_legacy_compat` | **1** | ✅ SSE stream 有意保留 |
| `admin_readonly_compat` | **0** | ✅ 迁入 `AdminInsights` |

### P1 — User 社交 / VIP ✅ **100%**

| 模块 | compat 余量 | 状态 |
|------|-------------|------|
| `user_compat` | **2** | ✅ OAuth 回调保留；其余迁入 proto |
| `user_memory_compat` | **0** | ✅ 迁入 `LlmChat` |
| `wave2_misc_compat` | **4** | ✅ 图片 multipart/静态保留；其余迁入 proto |

### P2 — Platform / LLM / WebSocket

| 模块 | 路由（约） | 说明 |
|------|-----------|------|
| `platform_compat` | ~17 | 文档、图片、配置、埋点 |
| `llm_read_compat` | ~2 | LLM 模型列表/目录（chat turn 已 proto） |
| WebSocket | 未计入 HTTP 路由表 | `api/internal` 无 websocket 残留；可能在 `httplegacy` 或独立 hub |

**问题**：WebSocket 不走 `google.api.http`；需单独 Kratos transport 或保留 compat 入口直至专用方案。

### P2 — `internal/apilegacy` 与 `rpc/pb/moe` 桥

| 问题 | 说明 |
|------|------|
| **伪 gRPC 网关** | `*gw` 包仍被 compat 路径调用，内部经 `moe_bridge` 转 `rpc/pb/moe` |
| **类型双份** | `adminv1.*FromMoe` / `*ToMoe` 遍布 service/compat；proto 已是 SSOT，桥应删除 |
| **biz 层 moe 引用** | `internal/biz/admin`、`llm`、`user` 等仍 import `rpc/pb/moe` |

**根因**：P6 把 message 抽到域 proto，但 compat 仍按旧 moe 形状做 JSON 转换。

**建议**：compat 退役时同步删除 `FromMoe/ToMoe`；biz 只认 `api/<domain>/v1` 类型。

### P3 — `api/defs` + `make gen-api` 风险（已缓解未消除）

| 问题 | 缓解 | 残余风险 |
|------|------|----------|
| goctl 覆盖 handler | `api-guard.sh` 提示 | 改 defs 仍可能还原 `api/internal/handler` |
| types 路径漂移 | **本轮** `sync-api-types-to-legacy.sh` | handler/routes 仍生成到 `api/internal/` |

**纪律**：生产路由变更禁止走 `make gen-api`；仅存量字段同步。

### P3 — `api/internal` 未完全清空

当前仅 3 个文件：

- `handler/routes_stub.go` — hybrid 构建桩
- `handler/README.md`
- `logic/.gitkeep`

**问题**：hybrid 构建标签若仍引用 `api/internal/handler`，无法物理删除目录。

### P4 — 进度指标 ✅ **已修正（2026-05-27）**

| 项 | 状态 |
|------|------|
| `PilotNativeCompatRoutes` | **45**（与各 `*_compat.go` 常量一致） |
| `nativeDomainRouteCount` | **227**（proto HTTP 路由计数） |
| `/migration` `percent` | **100**（`go test ./internal/platform/kratosprogress/...`） |

历史口径 `263` / `198` 已过时，仅作 P3 基线参考。见 [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md)。

---

## 5. 响应格式速查（给前后端联调）

### Proto HTTP（信封 + 平铺字段）

```json
// 成功 GET /api/posts
{ "code": 200, "message": "操作成功", "success": true, "posts": [...], "total": 10 }

// 错误
{ "code": 404, "message": "...", "success": false, "reason": "POST_NOT_FOUND" }
```

实现：`internal/server/http_envelope.go`，在 `NewHTTPServer` 全局挂载。

### Compat HTTP（经 `compatEnvelopeFilter` 压平后）

```json
{ "code": 200, "success": true, "message": "...", "posts": [...] }
// object data 字段合并到顶层；array/scalar 仍保留 data
```

实现：各 `httplegacy/*_compat.go` 内 `ctx.JSON` + `internal/server/compat_envelope.go` Filter。

### Flutter 解析 SSOT

`lib/services/api_response.dart` — `listOf` / `object` / `authSession` / `isSuccess` 同时兼容两种格式。

---

## 6. 推荐后续路线（D2→D4）

```text
阶段 0（P0）— 双轨契约 ✅
  compat 信封 · 删重复路由 · Flutter ApiResponse

阶段 A–B（P1）— Admin / User / 记忆 / wave2 ✅
  AdminApp · UserService/VipService · LlmChat · content/vipplans

阶段 C（P2）— Platform / LLM 读 / 社交余量 compat
  platform_compat（17）· community/chat/ai/checkin（19）· llm_read（2）
  → proto 注解 + grpc 适配 + compat no-op

阶段 D（D4 清理）
  删 httplegacy 死代码 + http_compat.go
  删 internal/apilegacy/*gw（保留 swagger bridge 至替代方案）
  rpc/pb/moe runtime 引用归零
  图片 upload 专用 transport 或 proto streaming
```

---

## 7. 验收命令

```bash
cd backend
make gen                    # proto pb/grpc/http
go build ./...
make check                  # moe-social build + 关键包测试

# 路由迁移进度（2026-05-27 口径）
curl -s http://127.0.0.1:8888/migration | jq .

# 抽测 proto 信封
curl -s 'http://127.0.0.1:8888/api/posts?page=1&page_size=1' | jq 'keys'

# 抽测 compat（压平后应与 proto 同形）
curl -s 'http://127.0.0.1:8888/api/platform/health' | jq 'keys'
```

---

## 8. 相关文件索引

| 文件 | 角色 |
|------|------|
| `internal/server/http.go` | HTTP 入口：CORS + compat/proto 信封 + Ops → Proto → Compat |
| `internal/server/http_envelope.go` | Proto 统一响应/错误编码 |
| `internal/server/compat_envelope.go` | Compat `BaseResp.data` 压平 Filter |
| `internal/server/cors.go` | Flutter Web CORS |
| `internal/server/http_proto.go` | 19 次 `Register*HTTPServer`（18 域） |
| `internal/server/http_compat.go` | compat 编排 |
| `internal/server/httplegacy/` | 存量 compat（**45** 条活跃） |
| `internal/server/httplegacy/route_stats.go` | `PilotNativeCompatRoutes` 进度常量 |
| `internal/apilegacy/swaggerdoc/` | Swagger UI / OpenAPI bridge |
| `scripts/gen/moe-proto.sh` | proto 生成（含 go-http） |
| `lib/services/api_response.dart` | Flutter 双格式解析 SSOT |

---

**维护者**：以本文 + `kratos-directory-ssot.md` 为架构收口 SSOT；状态板勾选见 `kratos-migration-status.md`。
