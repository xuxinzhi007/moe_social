# Backend Service

Moe Social 后端：**单进程 Kratos HTTP**（`make moe-social` → `:8888`）。

## 启动

```bash
cd backend
make moe-social          # 生产 / 本地
make moe-social-dev      # + deploy-agent :19010
make gen                 # proto + conf + 路由计数
make check               # 编译 + 单测
```

| 文档 | 用途 |
|------|------|
| [LAYOUT.md](LAYOUT.md) | 目录与 HTTP 装配 |
| [openapi.yaml](openapi.yaml) | Apifox / OpenAPI 3.0 |
| [docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md) | 迁移状态板 |
| [scripts/README.md](scripts/README.md) | 生成脚本 |

契约 SSOT：`api/<domain>/v1/*.proto` + `google.api.http` → `make gen`。

历史 go-zero / api+rpc 双进程已退役；见 [docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md) 与 [docs/dev/kratos-legacy-api-migration.md](../docs/dev/kratos-legacy-api-migration.md)。
