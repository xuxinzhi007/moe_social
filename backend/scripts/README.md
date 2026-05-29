# backend/scripts

## 唯一生成链路（Kratos）

```bash
cd backend
make gen    # proto pb/grpc/http + openapi.yaml + 路由计数
```

新接口：只改 `api/<domain>/v1/*.proto`（含 `google.api.http`），**禁止** goctl / `api/defs`。

| 命令 | 用途 |
|------|------|
| **`make gen`** | 域 proto → `*.pb.go`、`*_http.pb.go`、`openapi.yaml`、路由计数 |
| `make gen-swagger` | 仅重生 `openapi.yaml` |
| `make init-proto-tools` | 新机器安装 protoc 插件 |
| `make check` | 编译 `cmd/moe-social` + 核心单测 |

已退役：`make gen-api`、`make gen-legacy-goctl`（执行会报错并提示用 proto）。

OpenAPI / Apifox：[docs/dev/openapi-apifox.md](../docs/dev/openapi-apifox.md)

## 活跃目录

```text
scripts/gen/
  moe-proto.sh
  openapi.sh
  moe-conf.sh
  proto-route-count/
```

历史 goctl / FS-8 脚本 → `scripts/archive/`
