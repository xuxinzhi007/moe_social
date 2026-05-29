# cmd/ 入口

| 入口 | 命令 | 说明 |
|------|------|------|
| **moe-social** | `make moe-social` | 生产唯一主程序（Kratos HTTP :8888） |
| moe-social-stack | `make moe-social-dev` | 同上 + deploy-agent :19010 |
| migrate | `make db-migrate` | 数据库迁移 |
| deploy-agent | `make deploy-agent` | 部署调试代理 |

已删除：`cmd/dev`、`cmd/rpc-monitor`、`cmd/moe-kratos`、`cmd/moe-platform`、独立 `api`/`rpc` 二进制。
