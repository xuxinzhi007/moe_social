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
  openapi.yaml                     # OpenAPI 3.0（make gen 产出）

  internal/biz/<domain>/
  internal/service/<domain>/

  internal/server/
    http.go                 # NewHTTPServer（CORS + 双信封 Filter）
    http_envelope.go        # Proto 响应/错误信封
    compat_envelope.go      # Compat BaseResp.data 压平
    http_proto.go           # Register*HTTPServer（19 次注册）
    http_compat.go          # 编排 httplegacy（45 条余量）
    httplegacy/
    grpc/<domain>/          # adminapp、llm、vipplans、content…
    grpc.go

  internal/platform/{svc,wiring,moesocial,kratosprogress}/
  internal/apilegacy/swaggerdoc/   # /swagger UI + openapi.yaml 静态服务

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
| 域 proto | **`make gen`** | `*.pb.go`、`*_grpc.pb.go`、`*_http.pb.go`、**`openapi.yaml`** |
| 仅 OpenAPI 文档 | `make gen-swagger` | `openapi.yaml`（OpenAPI 3.0.3） |
| 路由表同步 | `make gen-http-routes` | `httplegacy/routes_*_gen.go` |
| 存量 defs | `make gen-api`（慎用） | handler + 可能在 `api/internal/types` 重生 types |

**OpenAPI / Apifox**：见 [openapi-apifox.md](./openapi-apifox.md)。

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

## 5. 参考实现（已迁入 proto HTTP · 2026-05-27）

| 域 | Proto | gRPC 适配 | 说明 |
|----|-------|-----------|------|
| Post / Gift / Notify | `api/post|gift|notify/v1` | `grpc/post` 等 | 社交基础 |
| User | `api/user/v1/user_messages.proto` | `grpc/user` | 登录/社交/钱包/OAuth（回调 2 条 compat） |
| Vip | `api/vip/v1/vip_messages.proto` | `grpc/vip` · `vipplans` | 用户 VIP + 管理端套餐 |
| Admin | `api/admin/v1/admin_messages.proto` | `grpc/adminapp` · `admininsights` | CRUD + 大盘 + legacy 运维 |
| Llm / 记忆 | `api/llm/v1/llm_messages.proto` | `grpc/llm` | chat turn + 用户记忆 8 路由 |
| MoeAdmin | `api/moe/v1/moe.proto` | `grpc/server.go` | 工具/大脑/推理状态 |
| Content | `api/content/v1/content.proto` | `grpc/content` | 内容生成 |
| Chat | `api/chat/v1/private_message.proto` | `grpc/chat` | 私信 + 推送通知 |

**仍走 httplegacy（45 条，P2）**：`platform`（17）· `community`（7）· `chat` 余量（6）· `ai`（4）· 图片静态（4）· OAuth 回调（2）· `llm_read`（2）· `checkin`（2）· SSE（1）。详见 [kratos-architecture-audit.md §2.4](./kratos-architecture-audit.md)。

---

## 6. 存量接口

老契约在 `api/defs`。**`make gen-api`** 会在 `api/internal/types` 重生 types（已迁到 `internal/legacy/types`），用后需手动合并或避免运行。业务维护在 `internal/biz` + `internal/service`；未迁 proto 的路径仍在 `httplegacy`。

迁移进度：`GET http://127.0.0.1:8888/migration`（**2026-05-27**：proto **227** · compat **45** · `percent=100`）。

---

## 7. 响应 JSON

### Proto 路由

由 `http_envelope.go` 包装：

```json
{ "code": 200, "message": "操作成功", "success": true, "posts": [], "total": 0 }
```

错误：`{ "code": <int>, "message": "...", "success": false, "reason": "..." }`。

### Compat 路由（P0 已压平）

compat handler 仍写 `BaseResp` + `data`，但 **`compat_envelope.go` Filter** 在写出前将 object `data` 合并到顶层，对外形状与 proto 一致。

跳过信封/压平：`/health`、`/migration`、`/swagger`、`/ws` 等。

Flutter：`lib/services/api_response.dart` 仍兼容历史 `data` 嵌套。

**新接口勿再增加 compat 路由。**
