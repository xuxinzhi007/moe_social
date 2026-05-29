# backend/scripts

## 新接口（Kratos）

新能力：`api/<domain>/v1/*.proto`（含 `google.api.http`）→ **`make gen`** → `internal/service` + `http_proto.go`。

完整步骤：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)

## 生成命令

| 命令 | 用途 |
|------|------|
| **`make gen`** | 域 proto → `*.pb.go`、`*_grpc.pb.go`、`*_http.pb.go` + conf + 路由表 |
| `make init-proto-tools` | 可选：新机器预装 protoc 插件（`make gen` 也会自动装） |
| `make gen-http-routes` | 同步 `internal/server/httplegacy/routes_*_gen.go` |
| `make gen-moe-proto` | 仅 proto pb/grpc/http |
| `make gen-api` | 改 `api/defs` 后（慎用） |
| `make check` | 编译 + 核心单测 |

## 覆盖范围

| 命令 | 会覆盖 | 不会动 |
|------|--------|--------|
| `make gen` | `api/**/v1/*.{pb,grpc.pb,http.pb}.go`、`httplegacy/routes_*_gen.go` | `internal/service`、手写 compat |

合并 Logic：[docs/dev/goctl-generation-hygiene.md](../docs/dev/goctl-generation-hygiene.md)

## 活跃目录

```text
scripts/gen/
  moe-proto.sh          # 含 --go-http_out
  moe-conf.sh
  http-routes/          → internal/server/httplegacy/routes_*_gen.go
  prune-api-logic-*.sh
```

已归档脚本 → [archive/README.md](./archive/README.md)
