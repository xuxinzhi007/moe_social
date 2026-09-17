# backend/scripts

## 唯一生成链路（Kratos）

```bash
cd backend
make gen    # 固定工具链生成 proto pb/grpc/http + openapi.yaml
make check-gen # 临时生成，只读比较当前工作树产物（不是 HEAD）
```

新接口：只改 `api/<domain>/v1/*.proto`（含 `google.api.http`），然后 `make gen`。

| 命令 | 用途 |
|------|------|
| **`make gen`** | 预检全部工具 → 域 proto pb/grpc/http → `openapi.yaml` |
| `make check-gen` | 临时生成并比较路径与字节，检测新增、缺失、陈旧产物，不覆盖工作树 |
| `make gen-swagger` | 同一预检，仅重生 `openapi.yaml` |
| `make init-proto-tools` | 显式安装 `proto-tools.sh` 固定版本的四个插件；protoc 本体自行安装 |
| `make check` | 格式、vet、生产入口编译与全仓单测（CGO 开启） |

版本唯一来源：`gen/proto-tools.sh`。工具缺失或版本不匹配会在生成前失败，不自动安装。插件版本核对 `go version -m` 的模块构建信息，而非显示 banner。先将 protoc 和插件目录放入本次命令的 PATH。

OpenAPI / Apifox：[docs/dev/openapi-apifox.md](../../docs/dev/openapi-apifox.md)

## 活跃目录

```text
scripts/gen/
  proto-tools.sh    # 版本固定、模块校验、显式安装
  moe-proto.sh      # 唯一有序生成流水线
  openapi.sh        # 仅 OpenAPI 入口
  check-gen.sh      # 只读产物检查
```

历史 goctl / FS-8 脚本 → `scripts/archive/`（灾难回滚用，日常勿跑）
