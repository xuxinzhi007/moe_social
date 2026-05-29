# Backend 布局（Kratos 生产）

> **更新：2026-05-29**  
> SSOT：[docs/dev/kratos-directory-ssot.md](../docs/dev/kratos-directory-ssot.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888 + gRPC :8080
```

---

## 目录结构

```text
cmd/moe-social/                      # 生产入口
config/config.yaml

api/<domain>/v1/*.proto              # 契约 SSOT
api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go

internal/biz/<domain>/
internal/data/<domain>/
internal/service/<domain>/

internal/server/
  http.go                            # NewHTTPServer
  http_proto.go                      # Register*HTTPServer（16 域）
  http_compat.go                     # 编排 httplegacy
  httplegacy/                        # 存量 compat（原 api/moehttp）
  grpc.go + grpc/<domain>/

internal/platform/
  svc/                               # ServiceContext（原 api/internal/svc）
  wiring/                            # 启动装配（原 api/runserver）
  moesocial/                         # 生产启动

internal/apilegacy/                  # 原 api/internal（gw/common/config）
internal/legacy/types/               # 原 api/internal/types

third_party/google/api/              # protoc HTTP 注解
```

---

## HTTP 装配顺序

```text
NewHTTPServer
  → RegisterOpsHTTP          # /health、/migration
  → RegisterProtoHTTP        # protoc-gen-go-http（官方）
  → RegisterCompatHTTP       # httplegacy（过渡，逐域缩短）
```

---

## `internal/server/httplegacy`

| 文件 | 作用 |
|------|------|
| `*_compat.go` | 未迁入 proto HTTP 的路由 |
| `deps.go` | `PilotDeps` |
| `routes_*_gen.go` | `make gen-http-routes` 生成 |

`register_all.go` 已删除；编排入口为 `http_compat.go`。

---

## 存量（非新接口）

| 路径 | 角色 |
|------|------|
| `api/defs/*.api` | goctl 契约（`make gen-api`） |
| `internal/legacy/types/` | goctl JSON types |
| `api/internal/handler/` | hybrid 残留 |
| `rpc/pb/moe/` | 冻结 bridge message |

---

## 数据流

```text
HTTP: Client → :8888 → http_proto / httplegacy → service → biz → data
gRPC: Client → :8080 → grpc/<domain> → service → biz → data
```

---

## 生成命令

| 场景 | 命令 |
|------|------|
| 改域 proto | **`make gen`** |
| 同步路由表 | `make gen-http-routes` |
| 改存量 defs | `make gen-api`（慎用） |

新机器可选：`make init-proto-tools`（`make gen` 也会自动装插件）。
