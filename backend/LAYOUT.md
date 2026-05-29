# Backend 布局（Kratos 生产）

> **更新：2026-05-27（P0/P1 收口）**  
> SSOT：[docs/dev/kratos-directory-ssot.md](../docs/dev/kratos-directory-ssot.md) · 状态板：[docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888 + gRPC :8080
```

**路由进度（2026-05-27）**：proto **227** · compat **45** · bridge **3** · `/migration percent=100`

---

## 目录结构

```text
cmd/moe-social/
config/config.yaml
openapi.yaml                         # make gen 产出（OpenAPI 3.0）

api/<domain>/v1/*.proto
api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go

internal/biz/<domain>/
internal/data/<domain>/
internal/service/<domain>/

internal/server/
  http.go                            # NewHTTPServer
  http_envelope.go                   # Proto 响应信封
  compat_envelope.go                 # Compat data 压平（P0）
  cors.go
  http_proto.go                      # Register*HTTPServer（19 次 / 18 域）
  http_compat.go                     # 编排 httplegacy
  httplegacy/                        # 45 条活跃 compat
  grpc.go + grpc/<domain>/           # adminapp、llm、vipplans、content…

internal/platform/
  svc/                               # ServiceContext
  wiring/                            # 启动装配
  moesocial/                         # 生产启动
  kratosprogress/                    # /migration

internal/apilegacy/swaggerdoc/       # /swagger UI + openapi.yaml
internal/legacy/types/

third_party/google/api/
```

---

## HTTP 装配顺序

```text
NewHTTPServer
  → corsFilter + compatEnvelopeFilter + EnvelopeResponseEncoder
  → RegisterOpsHTTP          # /health、/migration
  → RegisterProtoHTTP        # 227 条 proto 路由
  → RegisterCompatHTTP       # 45 条 compat
  → RegisterBridgeHTTP       # /swagger 三件套
```

---

## `internal/server/httplegacy`

| 文件 | 作用 |
|------|------|
| `*_compat.go` | 未迁入 proto 的路由（常量见各文件 `PilotNative*CompatRoutes`） |
| `route_stats.go` | `PilotNativeCompatRoutes` 合计 **45** |
| `routes_native_gen.go` | `nativeDomainRouteCount = 227` |
| `routes_bridge_gen.go` | `bridgeRouteCount = 3` |
| `deps.go` | `PilotDeps` |

活跃 compat 分布见 [docs/dev/kratos-architecture-audit.md §2.4](../docs/dev/kratos-architecture-audit.md)。

---

## 存量（非新接口）

| 路径 | 角色 |
|------|------|
| `api/defs/*.api` | goctl 契约（`make gen-api`） |
| `internal/legacy/types/` | goctl JSON types |
| `api/internal/handler/` | hybrid 残留 |
| `rpc/pb/moe/` | bridge message（D4 目标归零） |

---

## 数据流

```text
HTTP: Client → :8888 → grpc/<domain>（proto）或 httplegacy（compat）→ service → biz → data
gRPC: Client → :8080 → grpc/<domain> → service → biz → data
```

---

## 生成命令

| 场景 | 命令 |
|------|------|
| 改域 proto | **`make gen`**（含 `openapi.yaml`） |
| 仅 OpenAPI 文档 | `make gen-swagger` |
| 同步路由表 | `make gen-http-routes` |
| 改存量 defs | `make gen-api`（慎用） |

OpenAPI / Apifox：[docs/dev/openapi-apifox.md](../docs/dev/openapi-apifox.md)。  
新机器可选：`make init-proto-tools`（`make gen` 也会自动装插件）。
