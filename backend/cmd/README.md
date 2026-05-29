# cmd/ 入口说明

## 生产（单主程序）

| 入口 | 命令 | 说明 |
|------|------|------|
| **`moe-social`** | `make moe-social` | **SSOT**：单进程 Kratos HTTP `:8888` + gRPC `:8080` |

## 开发

| 入口 | 命令 | 说明 |
|------|------|------|
| `moe-social-stack` | `make moe-social-dev` | 同 `moe-social` + deploy-agent `:19010` + RPC debug `:19011` |

## 工具（独立进程，保留）

| 入口 | 命令 | 说明 |
|------|------|------|
| `migrate` | `make db-migrate` | 仅跑 schema 迁移后退出 |
| `deploy-agent` | `make deploy-agent` | 部署/调试代理（`:19010`） |
| `rpc-monitor` | `make rpc-monitor` | 独立 RPC 监控（一般用 stack 内建即可） |

## 已废弃 / 勿用于生产

| 入口 | 说明 |
|------|------|
| `dev` | 旧双进程（分别启动 `./rpc` + `./api`）；PK-8 后请用 `moe-social` |
| `moe-platform` | Makefile 残留 target，**目录不存在**；将移除 |

**结论**：日常只需 **`cmd/moe-social`** 一个主程序；其余为开发附加或一次性工具。
