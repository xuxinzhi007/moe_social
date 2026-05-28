# Backend 布局（Kratos 生产 · P5 完成）

> **更新：2026-05-28**  
> 状态：[docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md) · P5-D：[docs/dev/kratos-p5d-zero-gozero.md](../docs/dev/kratos-p5d-zero-gozero.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888 + gRPC :8080（依赖树零 go-zero）
```

配置 SSOT：`config/config.yaml`（`kratos_pure_enabled: true`、`super_grpc_retired: true`）。

---

## 目标目录结构（新接口按此开发）

```text
cmd/moe-social/                 # 入口
config/config.yaml              # 运行时

api/<domain>/v1/*.proto         # 契约 SSOT（新能力）
api/<domain>/v1/*.pb.go         # make gen

internal/biz/<domain>/          # 业务
internal/data/<domain>/         # 持久化（P4-D；20/21 域）
internal/service/<domain>/      # 应用服务
api/moehttp/                    # Kratos HTTP（*_compat.go 手维护）
internal/server/moekratoshttp/  # /health、/migration
internal/server/moegrpc/        # 12 域 gRPC + MoeAdmin
internal/platform/moesocial/    # 启动编排
```

**新接口**：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)  
**存量 compat 清单**：[docs/dev/kratos-legacy-api-migration.md](../docs/dev/kratos-legacy-api-migration.md)

---

## `api/moehttp`

| 文件模式 | 作用 |
|----------|------|
| `*_compat.go` | 按域 Kratos 路由 → `internal/service/*App` |
| `compat_invoke.go` | 共享 JSON 绑定辅助 |
| `register_all.go` | 统一注册入口 |
| `routes_native_gen.go` | **`nativeDomainRouteCount = 0`** |
| `routes_bridge_gen.go` | swagger 等 **2** 条 bridge |
| `route_stats.go` | `/migration` 进度口径 |

---

## 存量 / 回滚（默认构建不编译）

| 目录 | 角色 |
|------|------|
| `api/defs/*.api` | goctl HTTP 契约（慎改；`make gen-api`） |
| `api/internal/handler/**` | `//go:build hybrid` |
| `api/internal/logic/` | **已退役**（`.gitkeep`） |
| `api/internal/types` | goctl 请求/响应类型（compat 仍用） |
| `rpc/moe.proto` | message-only（**无** `service Super`） |
| `rpc/internal/bootstrap/` | MoeAdmin / Bot |
| `api/etc/moe.yaml`、`rpc/etc/moe.yaml` | goctl 结构片段，**非**端口 SSOT |

---

## 数据流

```text
HTTP 生产:
  Client → :8888 api/moehttp/<domain>_compat.go
         → internal/service/<domain>
         → internal/biz/<domain>
         → internal/data/<domain>（按需）

gRPC 生产:
  Client → :8080 internal/server/moegrpc/<domain>
         → internal/service/<domain> → biz → data
```

**不再经过**：go-zero `rest` 对外监听、`Super` gRPC、`api/internal/logic`。

---

## 生成命令

| 场景 | 命令 |
|------|------|
| 新域 proto / 日常 pb | `make gen` 或 `make gen-moe-proto` |
| 同步 Kratos 路由表 | `make gen-http-routes` |
| 改存量 `api/defs` | `make gen-api` |
| 改 `rpc` 契约 | `make gen-rpc` |
| 契约大改 | `make gen-all` |

详见 [scripts/README.md](scripts/README.md)。
