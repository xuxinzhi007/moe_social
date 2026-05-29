# Kratos 目录 SSOT（对齐官网 · Moe 改造）

> **权威参考**：[Kratos 项目布局](https://go-kratos.dev/zh-cn/docs/intro/layout/)  
> **状态板**：[kratos-migration-status.md](./kratos-migration-status.md)  
> **上次更新**：2026-05-29 · 迁移完成（HTTP-only）

---

## 1. 官方 HTTP 两步

```text
api/<domain>/v1/*.proto + google.api.http
  → make gen → *_http.pb.go
  → internal/server/http_proto.go → Register*HTTPServer
  → internal/server/protohttp/<domain>/ → service → biz → data
```

---

## 2. 当前目录

```text
backend/
  cmd/moe-social/
  api/<domain>/v1/*.proto, *_http.pb.go
  internal/server/protohttp/<domain>/    # proto HTTP 适配层
  internal/server/transport/           # OAuth / WS / SSE
  internal/platform/{svc,wiring,bootstrap,moesocial}/
  config/config.yaml
  openapi.yaml
  third_party/google/api/
```

---

## 3. `make gen` 与 `init-proto-tools`

| 命令 | 作用 |
|------|------|
| **`make gen`** | 日常：**足够**。跑 proto pb/grpc/http + conf + 路由表 |
| `make init-proto-tools` | **仅新机器一次**（可选）：手动预装 `protoc-gen-go` / `grpc` / `go-http` |

`gen-moe-proto` 若发现未安装 `protoc-gen-go-http`，会**自动 `go install`**，无需每次先跑 `init-proto-tools`。

```bash
cd backend && make gen    # 改 proto 后日常用这个
```

---

## 4. 代码生成

```bash
protoc --proto_path=. --proto_path=./third_party \
  --go_out=. --go-grpc_out=. --go-http_out=. \
  api/<domain>/v1/*.proto
```

| 命令 | 用途 |
|------|------|
| `make gen` | 域 proto → pb/grpc/http |
| `make gen-http-routes` | → `internal/server/httplegacy/routes_*_gen.go` |
| `make gen-api` | **存量** goctl；会重生 `api/internal/types`（已迁走，慎用） |

---

## 5. 迁移进度

### D0 — HTTP 生成链 ✅

- [x] `third_party/google/api/`
- [x] `protoc-gen-go-http` + `moe-proto.sh`
- [x] 18 域 `*_http.pb.go`（含 `content`、`admin` AdminApp、扩展 `user`/`vip`/`llm`）
- [x] `http_proto.go` → **19** 次 `Register*HTTPServer`（同域多 service 如 Vip/Chat/Admin）

### D1 — `api/` 瘦身 ✅（部分）

- [x] `api/moehttp/` → `internal/server/httplegacy/`
- [x] `api/runserver/` → `internal/platform/wiring/`
- [x] `api/internal/{svc,gw,common,…}` → `internal/apilegacy/` + `internal/platform/svc`
- [x] `api/internal/types` → `internal/legacy/types`
- [x] `api/defs/` 只读镜像 → `scripts/archive/api-defs/`

### D2 — compat → proto HTTP（~83%，P0/P1 ✅）

| 指标 | 数值 | 核对 |
|------|------|------|
| Proto HTTP 路由 | **254** | `api/**/*_http.pb.go` 中 `r.GET/POST/…` 计数 |
| Compat 活跃路由 | **11** | intentional only（OAuth/SSE/WS/multipart） |
| Bridge | **3** | `/swagger`、`/swagger/openapi.yaml`、`/swagger/doc.json` |
| `nativeDomainRouteCount` | **254** | `routes_native_gen.go` |
| `PilotNativeCompatRoutes` | **11** | `route_stats.go` |

**P0/P1 已迁入 proto（compat no-op 或仅保留例外）：**

- Admin：`admin_service`（55）· `admin_legacy`（28→1 SSE）· `admin_readonly`（3）
- User：社交/VIP/钱包/OAuth（40→2 OAuth 回调）
- 记忆：`user_memory`（8）→ `LlmChat`
- wave2：19→4（图片 multipart 静态保留）

**仍走 compat（intentional，11 条）：** OAuth（2）· SSE（1）· WebSocket（4）· 图片 multipart（4）。详见 [kratos-migration-status.md](./kratos-migration-status.md)。

**响应格式（P0 ✅）：** proto 走 `http_envelope.go`；compat 经 `compat_envelope.go` 压平后与 proto 同形。Flutter `api_response.dart` 仍兼容历史 `data` 嵌套。

### D3 — 清空 `api/internal` ⏳

- [x] 迁出 svc / gw / common / types
- [x] `api/internal` 仅保留 handler stub + logic `.gitkeep`（hybrid 构建用）
- [ ] 物理删除 `api/internal/handler`（待 hybrid 构建标签退役）

### D4 — httplegacy 死代码清库 ✅ Phase-0 + Phase-2（2026-05-29）

- [x] 删除 zero-route `*_compat.go` / convert / `admin_legacy_crud_handlers`（26 文件，~4.7k LOC）
- [x] `httplegacy` 零 `rpc/pb/moe` runtime import
- [x] `http_compat.go` 仅注册 intentional transport
- [x] `internal/apilegacy/*gw` 退役（15 包删除；`chatdelivery` + in-process `llm` gateway 替代）
- [x] `internal/biz` 内 `rpc/pb/moe` 引用归零（Phase-2）
- [x] `internal/apilegacy` 运行时 `rpc/pb/moe` 引用归零（Phase-2；`api/*/v1/moe_bridge*.go` 已删）
- [x] 删除 `api/*/v1/moe_bridge*.go` 与域 `grpc/*/convert.go`（Phase-3）
- [x] `MoeToolPort` / `pkg/moe` 直用域 `*v1`（Phase-3）；`make moe-social` 不链接 `rpc/pb/moe`

**现存问题清单** → [kratos-architecture-audit.md](./kratos-architecture-audit.md) §4

---

## 6. 新接口纪律

| ❌ | ✅ |
|----|-----|
| 新路由进 `api/defs` | `api/<domain>/v1/*.proto` + `google.api.http` |
| 新路由进 `httplegacy` | `make gen` + `Register*HTTPServer` |
| `make gen-api` 扩生产路由 | 仅存量维护 |

---

## 7. 相关文档

- [kratos-architecture-audit.md](./kratos-architecture-audit.md) — **结论与现存问题**
- [kratos-server-layout-migration.md](./kratos-server-layout-migration.md)
- [new-api-kratos.md](./new-api-kratos.md)
- [goctl-generation-hygiene.md](./goctl-generation-hygiene.md)
