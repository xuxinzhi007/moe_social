# Kratos 目录 SSOT（对齐官网 · Moe 改造）

> **权威参考**：[Kratos 项目布局](https://go-kratos.dev/zh-cn/docs/intro/layout/)  
> **状态板**：[kratos-migration-status.md](./kratos-migration-status.md)  
> **上次更新**：2026-05-29 · **审计结论**：[kratos-architecture-audit.md](./kratos-architecture-audit.md)

---

## 1. 官方 HTTP 两步（已对齐）

```text
api/<domain>/v1/*.proto + google.api.http
  → make gen → *_http.pb.go
  → internal/server/http.go
  → Register*HTTPServer（http_proto.go 调用生成代码）
  → internal/service → biz → data
```

过渡期旁路：`RegisterCompatHTTP` → `internal/server/httplegacy/*_compat.go`（逐域缩短，最终删除）。

---

## 2. 当前目录（2026-05-29）

```text
backend/
  api/<domain>/v1/*.proto, *.pb.go, *_grpc.pb.go, *_http.pb.go   # 契约 SSOT
  api/defs/*.api                    # 存量 goctl（勿扩；make gen-api）
  api/internal/handler/             # hybrid 构建残留
  api/internal/logic/.gitkeep

  internal/server/
    http.go                         # NewHTTPServer
    http_proto.go                   # Register*HTTPServer（17 域，含 AdminInsights）
    http_compat.go                  # 编排 httplegacy compat
    httplegacy/                     # 存量 compat（原 api/moehttp）
    grpc/ + grpc.go

  internal/platform/
    svc/                            # ServiceContext（原 api/internal/svc）
    wiring/                         # 启动装配（原 api/runserver）
    moesocial/                      # 生产 HTTP/gRPC 启动

  internal/apilegacy/               # 原 api/internal（gw/common/config/…）
  internal/legacy/types/            # 原 api/internal/types（goctl 契约 JSON）

  third_party/google/api/           # protoc-gen-go-http 依赖
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
- [x] 17 域 `*_http.pb.go`（含 admin AdminInsights）
- [x] `http_proto.go` → **17 域** `Register*HTTPServer`

### D1 — `api/` 瘦身 ✅（部分）

- [x] `api/moehttp/` → `internal/server/httplegacy/`
- [x] `api/runserver/` → `internal/platform/wiring/`
- [x] `api/internal/{svc,gw,common,…}` → `internal/apilegacy/` + `internal/platform/svc`
- [x] `api/internal/types` → `internal/legacy/types`
- [x] `api/internal/types` → `internal/legacy/types`
- [x] `api/defs/` 只读镜像 → `scripts/archive/api-defs/`（`moe.api` 仍 import 活跃 defs）

### D2 — compat → proto HTTP（进行中，~25%）

已迁入 proto HTTP 并摘除 compat 路由的域：post、landing、checkin（用户侧）、achievement、gift、comment、behavior、vipread、moeadmin、ai（CRUD）、notify（收件箱）、user（5 RPC）、community（4 RPC）、chat（私信）、vip（3 RPC）、**admin insights（5 路由）** 等。

仍走 compat（约 198 条活跃路由）：admin 大批量 CRUD、user 社交/VIP 余量、platform、llm 读、websocket 等。详见 [kratos-architecture-audit.md](./kratos-architecture-audit.md)。

### D3 — 清空 `api/internal` ⏳

- [x] 迁出 svc / gw / common / types
- [x] `api/internal` 仅保留 handler stub + logic `.gitkeep`（hybrid 构建用）
- [ ] 物理删除 `api/internal/handler`（待 hybrid 构建标签退役）

### D4 — 归零

- [ ] 删 `httplegacy/`、`http_compat.go`
- [ ] `rpc/pb/moe` runtime 零引用

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
