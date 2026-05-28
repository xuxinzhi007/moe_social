# 新接口开发（纯 Kratos 目录纪律）

> **生产入口**：`make moe-social`（Kratos HTTP `:8888` + gRPC `:8080`）  
> **不要再往** `api/defs/*.api` **加新路由**（存量维护可用 `make gen-api`，新能力走本文）。

---

## 1. 目录结构（与 core-platform 对齐）

```text
backend/
  cmd/moe-social/              # 进程入口
  config/config.yaml           # 运行时 SSOT

  api/<domain>/v1/*.proto      # ★ 新接口契约 SSOT（HTTP 路径写在 proto 注释）
  api/<domain>/v1/*.pb.go      # make gen 生成

  internal/biz/<domain>/       # ★ 业务逻辑
  internal/service/<domain>/   # ★ 应用服务（编排 biz，供 HTTP/gRPC 调用）

  api/moehttp/                 # Kratos HTTP 路由注册（*_compat.go 手维护）
  internal/server/moekratoshttp/  # /health、/migration
  internal/server/moegrpc/     # Kratos gRPC 实现（按需）

  internal/platform/moesocial/ # 启动、装配 deps

  ── 存量（勿为新接口扩展）──
  api/defs/*.api               # goctl 巨石分片，仅维护老接口
  api/internal/handler|logic/  # goctl 生成链
  rpc/                         # Super/MoeAdmin goctl gRPC
```

**请求路径（生产）**：

```text
Client → :8888  Kratos HTTP (api/moehttp)
              → internal/service/<domain>
              → internal/biz/<domain>
```

存量 200+ 路由仍经 `api/moehttp/routes_native_gen.go` 桥到 `api/internal/logic`（逐步按域迁出，新接口不要走这条链）。

---

## 2. `make gen` 能生成什么？

| 你做的修改 | 应执行的命令 | 生成物 |
|------------|--------------|--------|
| 新增/修改 `api/<domain>/v1/*.proto` | **`make gen`** | `*.pb.go`、`*_grpc.pb.go` |
| 仅同步 Kratos 路由表（未改 defs） | `make gen` | `api/moehttp/routes_*_gen.go` |
| 修改 `api/defs/*.api`（**存量**） | `make gen-api` | handler、types、routes.go + 上表路由 |
| 修改 `rpc` 契约 | `make gen-rpc` | rpc server/pb 等 |
| proto + defs 都改了 | `make gen-all` | 以上合并 |

**结论**：新接口只改域 proto 时，**`make gen` 足够生成 pb**；**不会**自动生成 `internal/service` 或 `api/moehttp` 注册代码（与 core-platform 一样，服务层手写的薄封装）。

---

## 3. 新 HTTP 接口步骤（推荐）

以域 `example`、路径 `GET /api/v1/example/items` 为例。

### 3.1 契约

新建 `api/example/v1/example.proto`：

```protobuf
syntax = "proto3";
package example.v1;
option go_package = "backend/api/example/v1;examplev1";

// HTTP: GET /api/v1/example/items?page=&page_size=
message ListItemsRequest { int32 page = 1; int32 page_size = 2; }
message ListItemsReply { repeated string names = 1; }

service ExampleAdmin {
  rpc ListItems(ListItemsRequest) returns (ListItemsReply);
}
```

### 3.2 生成 pb

```bash
cd backend
make gen    # 或 make gen-moe-proto
```

### 3.3 业务 + 服务

```bash
# 业务
internal/biz/example/list.go

# 应用服务（薄层）
internal/service/example/app.go   # 调用 biz，返回 proto 类型
```

### 3.4 HTTP 注册（Kratos）

在 `api/moehttp/example_compat.go` 中 `RegisterExampleCompat(srv, app)`，并在 `api/moehttp/register_all.go` 里调用。

在 `internal/platform/moesocial/kratos_front.go`（或 `pilotDepsFromAPI`）中注入 `ExampleApp`（若需 DB，挂到 `PilotDeps` / `svc.ServiceContext`）。

### 3.5 校验

```bash
make check
make moe-social
curl -s "http://127.0.0.1:8888/api/v1/example/items?page=1&page_size=10"
```

---

## 4. 禁止混用（评审清单）

| ❌ 不要 | ✅ 要 |
|--------|------|
| 新路由写进 `api/defs/*.api` | 写进 `api/<domain>/v1/*.proto` |
| 新逻辑只写在 `api/internal/logic` 且不迁 service | `internal/biz` + `internal/service` |
| 新接口只改 `routes_native_gen` | 写 `api/moehttp/*_compat.go` 并注册 |
| 指望 `make gen` 出 handler/logic | `make gen` 只出 pb；服务与路由手写 |

---

## 5. 参考实现

| 域 | Proto | Service | HTTP 注册 |
|----|-------|---------|-----------|
| VIP 读 | `api/vip/v1/vip_read.proto` | `internal/service/vip/` | `api/moehttp/vip_compat.go` |
| Landing | （RPC pb 复用） | `internal/service/landing/` | `api/moehttp/landing_compat.go` |
| Moe Admin | `api/moe/v1/moe.proto` | `internal/service/moe/` | `api/moehttp/admin_compat.go` |
| Admin Insights | `api/admin/v1/admin_insights.proto` | `internal/service/admin/` | `api/moehttp/admin_insights_compat.go` |

---

## 6. 存量接口维护

老接口仍在 `api/defs` + `api/internal/logic`：改契约用 **`make gen-api`**，逻辑仍在 `*logic.go` 里改；**不要**与上表新接口流程混在同一 PR 里新增 defs 路由。

迁移进度：`GET http://127.0.0.1:8888/migration`。
