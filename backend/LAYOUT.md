# Backend 布局（Kratos 生产 · PK-13+）

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888 + gRPC :8080
```

配置 SSOT：`config/config.yaml`。

---

## 目标目录结构（新接口按此开发）

```text
cmd/moe-social/                 # 入口
config/config.yaml              # 运行时

api/<domain>/v1/*.proto         # 契约 SSOT（新能力）
api/<domain>/v1/*.pb.go         # make gen / gen-moe-proto

internal/biz/<domain>/          # 业务
internal/service/<domain>/      # 应用服务
api/moehttp/                    # Kratos HTTP 路由（compat + routes_*_gen）
internal/server/moekratoshttp/  # /health、/migration
internal/server/moegrpc/        # Kratos gRPC（按需）
internal/platform/moesocial/    # 启动编排
```

**新接口开发手册**：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)

---

## 存量目录（维护老接口，勿扩展新路由）

| 目录 | 角色 |
|------|------|
| `api/defs/*.api` + `api/moe.api` | goctl HTTP 契约（FS-8 分片） |
| `api/internal/handler`、`logic`、`types` | goctl 生成 + 存量实现 |
| `api/moehttp/routes_*_gen.go` | 从 `routes.go` 同步的 Kratos 桥（`make gen-http-routes`） |
| `rpc/` | Super / MoeAdmin goctl gRPC |
| `api/etc/moe.yaml`、`rpc/etc/moe.yaml` | goctl 结构片段，**不是**运行时端口 SSOT |

---

## 数据流

```text
新接口:
  Client → :8888 api/moehttp (*_compat.go)
         → internal/service/<domain>
         → internal/biz/<domain>

存量 (~247 路由):
  Client → :8888 api/moehttp (routes_native_gen.go)
         → api/internal/logic → *gw → biz

gRPC:
  Client → :8080 internal/server/moegrpc 或 rpc/server
         → rpc/logic 或 service → biz
```

---

## 生成命令

| 场景 | 命令 |
|------|------|
| 新域 proto / 日常 pb | `make gen` |
| 改存量 `api/defs` | `make gen-api` |
| 改 `rpc` 契约 | `make gen-rpc` |
| 契约大改 | `make gen-all` |

详见 [scripts/README.md](scripts/README.md)。
