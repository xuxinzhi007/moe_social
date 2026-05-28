# moe-social 运行时

> **更新：2026-05-27** · 架构：[kratos-migration.md](./kratos-migration.md) · 目录：[backend/LAYOUT.md](../../backend/LAYOUT.md)

## 是什么？

**一个 OS 进程**，**纯 Kratos 对外传输**（HTTP `:8888` + gRPC `:8080`），内部仍复用 goctl 生成的 handler/logic 与 RPC logic（逐步迁到 `internal/service`）。

| 维度 | 说明 |
|------|------|
| 入口 | `cmd/moe-social`（`-f config/config.yaml`） |
| 开发附加 | `make moe-social-dev` → deploy-agent `:19010`、RPC debug `:19011` |
| 配置 SSOT | `backend/config/config.yaml` |
| goctl 片段 | `api/etc/moe.yaml`、`rpc/etc/moe.yaml`（结构/依赖，**不是**端口 SSOT） |

## 启动

```bash
cd backend
make moe-social
make moe-social-stop   # 端口占用时
```

成功日志含：`pure Kratos HTTP`、`:8888`、`:8080`。

## 请求路径

```text
HTTP  Client → :8888
              → api/moehttp (Kratos)
              → [compat] internal/service
              → [存量] api/internal/logic → *gw → biz

gRPC  Client → :8080 → rpc/logic 或 moegrpc → biz
```

## 生成（与运行时无关）

| 改什么 | 命令 |
|--------|------|
| 域 proto | `make gen` |
| 存量 `api/defs` | `make gen-api` |
| rpc 契约 | `make gen-rpc` |

见 [backend/scripts/README.md](../../backend/scripts/README.md)、[new-api-kratos.md](./new-api-kratos.md)。

## 观测

```bash
curl -s http://127.0.0.1:8888/health
curl -s http://127.0.0.1:8888/migration
```

## 已废弃

- 双进程 `make api` + `make rpc` 作为生产形态
- `make moe-kratos`（:1903x 试点）
- `make verify-sprint-fs9` 等验收 target
