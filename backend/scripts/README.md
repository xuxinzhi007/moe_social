# backend/scripts

## 日常命令

| 命令 | 说明 |
|------|------|
| `make gen` | 域 proto + conf + RPC + `api/moehttp` 路由 |
| `make gen-http-routes` | 仅同步 HTTP 路由（改 `routes.go` 后） |
| `make check` | 编译 `cmd/moe-social` + 核心包单测 |
| `make moe-social` | 生产单进程（:8888 + :8080） |

## 目录

```text
scripts/
  gen/                    # 代码生成（Makefile 唯一入口）
    moe-proto.sh          # api/*/v1、rpc 域 proto
    moe-conf.sh           # internal/conf
    http-routes/          # → api/moehttp/routes_*_gen.go
    fs8-*.py              # RPC defs 切分/组装
    fs9*.sh               # goctl RPC 后处理
    api-guard.sh          # gen-api 门禁
    post-gen-check.sh     # 生成后空壳检查
  tools/
    fs9b-rewrite-imports/ # 一次性 import 重写（慎用）
  fs8-split-super-proto.py  # 从单体 moe.proto 切分（慎用）
```

迁移验收脚本已移除；改 Kratos/路由后跑 `make check` 与 `make moe-social` 手测即可。

运行时布局见 [LAYOUT.md](../LAYOUT.md)。
