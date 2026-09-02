# moe-social 运行时

> **最后更新：2026-05-29**  
> 架构：[kratos-migration.md](./kratos-migration.md) · 状态：[kratos-migration-status.md](./kratos-migration-status.md) · P5-D：[kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md)

## 是什么？

**一个 OS 进程**（`cmd/moe-social`），对外 **纯 Kratos**：

| 维度 | 说明 |
|------|------|
| HTTP | Kratos `:8888` → `http_proto`（官方）+ `httplegacy`（过渡 compat） |
| gRPC | Kratos `:8080` → `internal/server/grpc`（12 域 + MoeAdmin） |
| 配置 SSOT | `backend/config/config.yaml` |
| go-zero | **默认构建不进入依赖树**（P5-D）；回滚见下文 |

| 开发附加 | `make moe-social-dev` → deploy-agent `:19010`、RPC debug `:19011` |
| goctl 片段 | `api/etc/moe.yaml`、`rpc/etc/moe.yaml`（结构模板，**端口以 config.yaml 为准**） |

## 启动

```bash
cd backend
make moe-social
make moe-social-stop   # 端口占用时
```

成功日志应含：`pure Kratos HTTP`、`Kratos gRPC`、`complete 100%`（或相近）。

## 请求路径（生产）

```text
HTTP  Client → :8888
              → internal/server/http.go（NewHTTPServer）
              → RegisterProtoHTTP（Register*HTTPServer）
              → RegisterCompatHTTP（httplegacy，仅未迁入 proto 的路由）
              → internal/service → biz

gRPC  Client → :8080
              → internal/server/grpc/<domain>
              → internal/service/<domain> → biz
```

**不再经过**：go-zero `rest` 对外监听、`Super` gRPC、`api/internal/handler`（默认构建）。

compat 余量清单：[kratos-legacy-api-migration.md §2.1](./kratos-legacy-api-migration.md#21-httplegacy-compat-清单)

## 紧急回滚（go-zero / zrpc）

仅当需要 PK-4 内网回退或旧式双进程调试：

```bash
cd backend
go build -tags hybrid -o bin/moe-social-hybrid ./cmd/moe-social
# 或单独 API/RPC 二进制：见 api/super.go、rpc/super.go（hybrid）
```

生产配置应保持 `kratos_pure_enabled: true`、`super_grpc_retired: true`。

## 生成（与运行时无关）

| 改什么 | 命令 |
|--------|------|
| 域 proto + 路由同步 | `make gen` |
| 存量 `api/defs` | `make gen-api`（慎用；handler 为 hybrid） |
| rpc message 组装 | `make gen-rpc`（无 goctl zrpc 业务 logic） |

见 [backend/scripts/README.md](../../backend/scripts/README.md)、[new-api-kratos.md](./new-api-kratos.md)。

## 观测与冒烟

```bash
curl -s http://127.0.0.1:8888/health
curl -s http://127.0.0.1:8888/migration | jq '{percent, rollout_percent, breakdown}'

# 域 gRPC：按域 proto 用 grpcurl 逐域验证（需服务已启动）
```

## 生产零 go-zero 自检

```bash
cd backend
go build ./cmd/moe-social
go list -deps ./cmd/moe-social | grep go-zero   # 应无输出
```

## 已废弃

- 双进程 `make api` + `make rpc` 作为**生产**形态
- `make moe-kratos`（:1903x 试点）
- `make verify-sprint-fs9` 等验收 target
- 默认路径依赖 `Super` gRPC 或 `rpc/internal/logic`
