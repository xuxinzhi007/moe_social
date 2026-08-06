# backend/scripts

## 唯一生成链路（Kratos）

```bash
cd backend
make gen    # proto pb/grpc/http + openapi.yaml + 路由计数
```

新接口：只改 `api/<domain>/v1/*.proto`（含 `google.api.http`），然后 `make gen`。

| 命令 | 用途 |
|------|------|
| **`make gen`** | 域 proto → `*.pb.go`、`*_http.pb.go`、路由计数；`gen-moe-proto` 末尾会调用 `openapi.sh` 更新 `openapi.yaml` |
| `make gen-swagger` | 仅重生 `openapi.yaml`（调试用；日常已被 `make gen` 覆盖） |
| `make init-proto-tools` | 新机器安装 protoc 插件 |
| `make check` | 编译 `cmd/moe-social` + 核心单测 |

OpenAPI / Apifox：[docs/dev/openapi-apifox.md](../../docs/dev/openapi-apifox.md)

## 活跃目录

```text
scripts/gen/
  moe-proto.sh
  openapi.sh
  moe-conf.sh
  proto-route-count/
```

历史 goctl / FS-8 脚本 → `scripts/archive/`（灾难回滚用，日常勿跑）
