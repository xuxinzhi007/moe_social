# Backend 布局（Kratos 生产）

> **更新：2026-05-29**  
> SSOT：[docs/dev/kratos-directory-ssot.md](../docs/dev/kratos-directory-ssot.md) · 状态板：[docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888
make gen           # proto + conf + HTTP 路由计数
```

**路由进度（2026-05-29）**：proto **258** · transport **7** · swagger **3** · `d2_proto_http_pct` **100%**

---

## 目录结构

```text
cmd/moe-social/
config/config.yaml
openapi.yaml                         # make gen 产出

api/<domain>/v1/*.proto
api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go

internal/biz/<domain>/
internal/data/<domain>/
internal/service/<domain>/

internal/server/
  http.go                            # NewHTTPServer（唯一装配入口）
  http_proto.go                      # Register*HTTPServer
  http_transport.go                  # OAuth / WS / SSE
  http_docs.go                       # /swagger
  http_envelope.go                   # Proto JSON 信封
  transport/                         # 非 JSON transport handlers
  routestats/                        # /migration 路由指标（make gen 更新 proto 计数）
  grpc/<domain>/                     # proto HTTP server 实现

internal/platform/
  svc/                               # ServiceContext
  wiring/                            # 启动装配
  bootstrap/                         # 成就钩子、Bot 调度、私信清理
  moesocial/                         # 生产启动
  kratosprogress/                    # /migration

internal/apilegacy/swaggerdoc/       # Swagger UI
internal/legacy/types/               # OAuth/SSE 请求类型（待逐步 proto 化）

third_party/google/api/
```

---

## HTTP 装配顺序

```text
NewHTTPServer
  → corsFilter + EnvelopeResponseEncoder
  → RegisterOpsHTTP
  → RegisterProtoHTTP
  → RegisterDocsHTTP
  → RegisterTransportHTTP
```

---

## 归档

| 路径 | 角色 |
|------|------|
| `scripts/archive/rpc-retired/` | 已删除的 `backend/rpc/` 契约分片与说明 |
| `api/super_stub.go` | 独立 api 二进制已移除 |

---

## 数据流

```text
HTTP: Client → :8888 → grpc/<domain>（proto HTTP）或 transport（OAuth/WS/SSE）→ service → biz
```
