# Backend 布局（Kratos 生产）

> **更新：2026-05-29**  
> SSOT：[docs/dev/kratos-directory-ssot.md](../docs/dev/kratos-directory-ssot.md) · 状态板：[docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888
make gen           # proto + conf + HTTP 路由计数
```

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
  protohttp/<domain>/                # proto HTTP 适配层（实现 *_http.pb.go）
  transport/                         # 非 JSON transport handlers
  routestats/                        # /migration 路由指标

internal/platform/
  svc/                               # ServiceContext
  wiring/                            # 启动装配
  bootstrap/                         # 成就钩子、Bot 调度
  moesocial/                         # 生产启动

internal/apilegacy/swaggerdoc/       # Swagger UI
internal/legacy/types/               # OAuth/SSE 类型（待 proto 化）

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

## 数据流

```text
Client → :8888 → protohttp/<domain> 或 transport → service → biz → data
```
