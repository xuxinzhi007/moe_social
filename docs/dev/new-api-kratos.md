# 新接口开发（纯 Kratos · 对齐官网）

> **生产入口**：`cd backend && make moe-social` → 单进程 Kratos HTTP `:8888`（**无对外 gRPC 监听**）
> **目录 SSOT**：[kratos-directory-ssot.md](./kratos-directory-ssot.md)（⚠️ 该篇已标注归档）· [moe-social-runtime.md](./moe-social-runtime.md)
> **新路由一律走域 proto** `backend/api/<domain>/v1/*.proto` 的 `google.api.http`，改完 `make gen`。
> **最后核对：2026-09-11**（目录树删掉已不存在的 `moeconf`、补上 `appdb`/`yamlconf` 等 5 个实际存在的包；`27 个域` 与 `28 处 Register*HTTPServer` 经 `ls` / `grep -c` 实测确认无误）

> ⚠️ 本文旧版描述的 `httplegacy` / `compat` 过渡层**已整体删除**：仓库内无 `httplegacy/` 目录、无 `RegisterCompatHTTP`、无 `compat_envelope.go`、无 `http_compat.go`、无 `internal/server/grpc/`。`api/defs/*.api`（go-zero IDL）目录亦已删除。全部路由现在都是 proto 路由。

---

## 1. 目录结构（当前有效）

```text
backend/
  cmd/moe-social/                  # 唯一生产入口
  config/config.yaml               # 配置 SSOT（端口取 runtime.http_port）

  api/<domain>/v1/*.proto                    # ★ 契约 SSOT（含 google.api.http）
  api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go   # make gen 产出
  api/etc/moe.yaml                            # API 结构片段（runtime.api_config_fragment）
  openapi.yaml                                # OpenAPI 3.0（make gen 产出）

  internal/biz/<domain>/
  internal/service/<domain>/

  internal/server/
    http.go                 # NewHTTPServer（CORS + 信封 Filter）；直挂 /health、/kratos/v1/moe/runtimes
    http_envelope.go        # Proto 响应/错误信封
    http_proto.go           # RegisterProtoHTTP → 28 处 Register*HTTPServer
    http_deps.go            # ProtoHTTPDeps / ProtoHTTPDepsFromServiceContext
    auth.go · cors.go · request_log.go · http_ops.go · http_docs.go · deps.go
    protohttp/<domain>/     # 27 个域的 Server + handler
    transport/              # websocket / sse / oauth / bind 等非 proto 通道
    swaggerdoc/             # /swagger UI + openapi.yaml 静态服务

  internal/platform/{svc,wiring,moesocial,moewiring,apicomm,apiconfig,appdb,yamlconf,moelog,chatdelivery,socialhook,bootstrap}/
    # ↑ moeconf 已于 2026-09-09 整包删除；配置读取 SSOT 现在是 backend/pkg/conf（不在 platform 下）
    # yamlconf 只加载 -f-api 指定的 API 结构片段（api/etc/moe.yaml），不读 config.yaml
  internal/legacy/types/    # 旧 go-zero types（仅存量结构体，无路由）
```

**生产请求路径**：

```text
Client → :8888
  → internal/server/http.go  NewHTTPServer(addr, deps)
  → RegisterProtoHTTP(srv, deps.Proto)        # http_proto.go:113
  → internal/server/protohttp/<domain>
  → internal/service/<domain> → internal/biz → internal/data
```

---

## 2. `make gen` 做什么？

| 修改 | 命令 | 产出 |
|------|------|------|
| 域 proto | **`make gen`** | `*.pb.go`、`*_grpc.pb.go`、`*_http.pb.go`、**`openapi.yaml`** |
| 仅 OpenAPI 文档 | `make gen-swagger` | `openapi.yaml`（OpenAPI 3.0.3） |
| 只读产物检查 | `make check-gen` | 临时生成并比较当前工作树路径和内容，检测新增、缺失、陈旧产物 |
| 单模块 proto | `make api-one PROTO=api/<mod>/v1/<mod>.proto` | 该模块三个 `.pb.go`（OpenAPI 用 `make gen` 同步） |
| 管理台 gen + 编译 | `make gen-moe-admin` | 见 `scripts/gen/moe-admin.sh` |

> ✗ 已删除的 target：`make gen-api`、`make gen-rpc`、`make gen-http-routes`、`make audit-logic-orphans`。日常契约生成用 `make gen`。

**OpenAPI / Apifox**：见 [openapi-apifox.md](./openapi-apifox.md)。

**日常只改 proto 时：`make gen` 足够。**

- 工具链是 `protoc` + `protoc-gen-go` / `-go-grpc` / `-go-http` / `-openapi`，**不再需要 goctl**。
- 版本唯一来源为 `backend/scripts/gen/proto-tools.sh`：protoc 33.1、Go 插件 v1.36.11、gRPC 插件 v1.6.0、HTTP 插件模块 v2.0.0-20260327083312-4ed1bedbb024、gnostic v0.7.1。
- `make init-proto-tools` 显式安装固定版本的四个插件；protoc 本体自行安装。将它们加入本次命令的 PATH。生成不会自动安装；任一工具缺失或版本不符，写产物前即失败。插件用 `go version -m` 校验模块版本，不使用 HTTP 插件的显示 banner。
- 输入按稳定顺序排序，先生成 Go 契约再生成 OpenAPI；涉及生成的 Make 调用即使传 `-j` 也串行执行。`make check-gen` 不比较 HEAD，也不覆盖脏工作树；多余旧产物会报错，需要审阅后处理。

`make gen` **不会**生成 `internal/service` 或服务装配代码——需在 `http_proto.go` 增加 `Register*HTTPServer`。arena/pet 的契约产物正常生成，但仍用该文件中的手写路由注册，不追加生成路由。

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
internal/service/example/example.go              # AppService + New
internal/service/example/example_<feature>.go    # 按功能拆分（可选）
internal/server/protohttp/example/example.go     # Server + New + handler
internal/server/protohttp/example/example_<feature>.go
```

**文件命名**：`{domain}.go` 放结构体与构造函数；`{domain}_{feature}.go` 按职责拆分（如 `user_login.go`、`post_write.go`）。禁止新增 `app.go` / `service.go` / 域级 `server.go`。

### 3.4 注册 HTTP

在 `internal/server/http_proto.go` 的 `RegisterProtoHTTP` 内增加：

```go
if d.ExampleApp != nil {
  examplev1.RegisterExampleServiceHTTPServer(srv, examplegrpc.New(d.ExampleApp))
}
```

在 `internal/server/http_deps.go` 的 `ProtoHTTPDeps` 加字段，并在 `ProtoHTTPDepsFromServiceContext`（:34）注入 `ExampleApp`。

### 3.5 校验

```bash
cd backend
make check-gen      # 当前工作树契约产物的只读检查
make check          # 格式、vet、生产入口编译与全仓单测（CGO 开启）
make moe-social
curl -s "http://127.0.0.1:8888/api/v1/example/items?page=1"
```

---

## 4. 禁止混用

| ❌ | ✅ |
|----|-----|
| 找 `api/defs` 加路由 | 目录已删；改 `api/<domain>/v1/*.proto` + `google.api.http` |
| 找 `httplegacy` 加路由 | 目录已删；`make gen` + `http_proto.go` |
| 指望 `make gen` 出 handler / service | 手写 `internal/service` + `internal/server/protohttp` |
| 跑 `make gen-api` / `make gen-rpc` | target 已删；用 `make gen` |
| 业务写回 `api/internal/logic` | 目录已删；写 `internal/biz` |

---

## 5. 参考实现

`internal/server/protohttp/` 下已有 **27** 个域适配，可直接照抄：

| 域 | Proto | HTTP 适配 | 说明 |
|----|-------|-----------|------|
| Post / Comment / Gift / Notify | `api/post|comment|gift|notify/v1` | `protohttp/post` 等 | 社交基础 |
| User | `api/user/v1/user_messages.proto` | `protohttp/user` | 登录/社交/钱包 |
| Admin | `api/admin/v1/admin_messages.proto` | `protohttp/adminapp` · `protohttp/admininsights` | 管理台 |
| MoeAdmin | `api/moe/v1/moe.proto` | `protohttp/moe_extended.go` | 工具/大脑 |

完整目录清单（`ls backend/internal/server/protohttp/`）：
`achievement` `adminapp` `admininsights` `ai` `arena` `battle` `behavior` `chat` `checkin` `comment` `community` `companion` `content` `game` `gift` `landing` `life` `llm` `media` `notify` `pet` `platform` `post` `user` `vip` `vipplans` `vipread`

> 旧版本文这里列的「仍走 httplegacy（45 条，P2）」清单已作废——compat 层已删除，全部路由均为 proto 路由。

---

## 6. 存量接口

老契约 `api/defs` 与 `api/internal/types` **均已删除**；残留的旧结构体在 `internal/legacy/types/types.go`，仅供 handler 复用，不再由任何生成器产出。

业务维护在 `internal/biz` + `internal/service`。

静态路由计数包及生成器已移除：生成函数数量不是实际注册路由数。需要路由集合时应枚举装配后的 HTTP server，不能从 `.pb.go` 推断生产启用情况。
⚠️ 旧文档提到的 `GET :8888/migration` 路由**已不存在**；`internal/server/http.go:35-37` 只直挂 `/health` 与 `/kratos/v1/moe/runtimes`。

---

## 7. 响应 JSON

### 成功信封

`internal/server/http_envelope.go:84` `marshalEnvelopeSuccess` 实测输出——proto 字段**嵌在 `data` 里**，不是压平到顶层：

```json
{ "code": 200, "success": true, "message": "操作成功", "data": { "posts": [], "total": 0 } }
```

### 错误信封

`http_envelope.go:53` `EnvelopeErrorEncoder`：

```json
{ "code": 500, "message": "...", "success": false, "reason": "..." }
```

`reason` 仅在有值时出现。HTTP 状态码由 `mapErrorHTTPStatus` 从 Kratos 错误码映射。

### 跳过信封的路径

`envelopeSkipPrefixes`（`http_envelope.go:21-25`）实测只有三条前缀：

| 前缀 | 说明 |
|------|------|
| `/health` | 健康检查 |
| `/swagger` | Swagger UI |
| `/doc` | 文档静态 |

> ⚠️ 旧版本文称 `/migration`、`/ws` 也跳过——`/migration` 路由已不存在；`/ws/*`（`internal/server/transport/websocket.go:23-27`）走 WebSocket 升级，不经过 JSON 编码器。

### Flutter 侧

`lib/services/api_response.dart` 兼容历史 `data` 嵌套，与上述信封一致。
