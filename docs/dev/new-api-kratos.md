# 新接口开发（纯 Kratos · 对齐官网）

> **生产入口**：`make moe-social`（Kratos HTTP `:8888` + gRPC `:8080`）  
> **目录 SSOT**：[kratos-directory-ssot.md](./kratos-directory-ssot.md)  
> **勿往** `api/defs/*.api` **加新路由**。

---

## 1. 目录结构（当前有效）

```text
backend/
  cmd/moe-social/
  config/config.yaml

  api/<domain>/v1/*.proto          # ★ 契约 SSOT（含 google.api.http）
  api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go   # make gen

  internal/biz/<domain>/
  internal/service/<domain>/

  internal/server/
    http.go              # NewHTTPServer
    http_proto.go        # Register*HTTPServer（官方生成路由）
    http_compat.go       # 编排 httplegacy（过渡）
    httplegacy/           # 存量 compat（逐域删除）
    grpc/ + grpc.go

  internal/platform/{svc,wiring,moesocial}/

  ── 存量（勿为新接口扩展）──
  api/defs/*.api
  internal/legacy/types/       # 原 goctl JSON types
  internal/apilegacy/          # 原 api/internal gw/common
  api/internal/handler/        # hybrid 残留
```

**生产请求路径**：

```text
Client → :8888
  → RegisterProtoHTTP（proto 生成路由，优先）
  → RegisterCompatHTTP（httplegacy，仅未迁入 proto 的路由）
  → internal/service → internal/biz → internal/data
```

---

## 2. `make gen` 做什么？

| 修改 | 命令 | 产出 |
|------|------|------|
| 域 proto | **`make gen`** | `*.pb.go`、`*_grpc.pb.go`、`*_http.pb.go` |
| 路由表同步 | `make gen-http-routes` | `httplegacy/routes_*_gen.go` |
| 存量 defs | `make gen-api`（慎用） | handler + 可能在 `api/internal/types` 重生 types |

**日常只改 proto 时：`make gen` 足够。**

- 新机器若缺 `protoc-gen-go-http`，`make gen` 会**自动 `go install`**。
- 可选预装：`make init-proto-tools`（仅一次）。

`make gen` **不会**生成 `internal/service` 或 HTTP 注册代码——需在 `http_proto.go` 增加 `Register*HTTPServer`（与 core-platform 相同）。

---

## 3. 新 HTTP 接口步骤

### 3.1 Proto 契约

```protobuf
syntax = "proto3";
package example.v1;

import "google/api/annotations.proto";

option go_package = "backend/api/example/v1;examplev1";

message ListItemsRequest { int32 page = 1; int32 page_size = 2; }
message ListItemsReply { repeated string names = 1; }

service ExampleService {
  rpc ListItems(ListItemsRequest) returns (ListItemsReply) {
    option (google.api.http) = { get: "/api/v1/example/items" };
  }
}
```

### 3.2 生成

```bash
cd backend && make gen
```

### 3.3 业务 + 服务

```text
internal/biz/example/
internal/service/example/app.go
internal/server/grpc/example/server.go   # 可选，与 HTTP 共用
```

### 3.4 注册 HTTP（官方）

在 `internal/server/http_proto.go` 增加：

```go
if d.ExampleApp != nil {
  examplev1.RegisterExampleServiceHTTPServer(srv, examplegrpc.New(d.ExampleApp))
}
```

在 `internal/server/http_deps.go` 的 `ProtoHTTPDepsFromPilot` 注入 `ExampleApp`。

**不要**再往 `httplegacy/*_compat.go` 加新路由。

### 3.5 校验

```bash
make check && make moe-social
curl -s "http://127.0.0.1:8888/api/v1/example/items?page=1"
```

---

## 4. 禁止混用

| ❌ | ✅ |
|----|-----|
| 新路由进 `api/defs` | `api/<domain>/v1/*.proto` + `google.api.http` |
| 新路由进 `httplegacy` | `make gen` + `http_proto.go` |
| 指望 `make gen` 出 handler | 手写 service + Register*HTTPServer |
| `make gen-api` 扩生产路由 | 仅存量维护 |

---

## 5. 参考实现（已迁入 proto HTTP）

| 域 | Proto | Service | HTTP 注册 |
|----|-------|---------|-----------|
| Post | `api/post/v1/post.proto` | `internal/service/post/` | `http_proto.go` → `RegisterPostServiceHTTPServer` |
| Gift | `api/gift/v1/gift.proto` | `internal/service/gift/` | 同上 |
| Notify | `api/notify/v1/notify.proto` | `internal/service/notify/` | 同上 |
| User（5 RPC） | `api/user/v1/user_messages.proto` | `internal/service/user/` | 同上 |
| MoeAdmin | `api/moe/v1/moe.proto` | `internal/service/moe/` | 同上 |

仍走 **httplegacy** 的域：admin 大批量 CRUD、user 社交余量、platform、llm 读配置等。见 [kratos-directory-ssot.md §D2](./kratos-directory-ssot.md)。

---

## 6. 存量接口

老契约在 `api/defs`。**`make gen-api`** 会在 `api/internal/types` 重生 types（已迁到 `internal/legacy/types`），用后需手动合并或避免运行。业务维护在 `internal/biz` + `internal/service` + `httplegacy`。

迁移进度：`GET http://127.0.0.1:8888/migration`。
