# Backend 布局（Kratos 生产）

> **更新：2026-05-29**  
> 状态：[docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888 + gRPC :8080
```

配置 SSOT：`config/config.yaml`（`kratos_pure_enabled: true`、`super_grpc_retired: true`）。

---

## 目标目录结构（与 core-platform 对齐）

```text
cmd/moe-social/                 # 入口
config/config.yaml              # 运行时 SSOT

api/<domain>/v1/*.proto         # 契约 SSOT（新能力）
api/<domain>/v1/*.pb.go         # make gen

internal/biz/<domain>/          # 业务
internal/data/<domain>/         # 持久化
internal/service/<domain>/      # 应用服务
api/moehttp/                    # Kratos HTTP（*_compat.go）
internal/server/moekratoshttp/  # /health、/migration
internal/server/moegrpc/        # 12 域 gRPC + MoeAdmin
internal/platform/moesocial/    # 启动编排
```

**新接口**：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)  
**存量 compat**：[docs/dev/kratos-legacy-api-migration.md](../docs/dev/kratos-legacy-api-migration.md)

---

## `api/moehttp`

| 文件模式 | 作用 |
|----------|------|
| `*_compat.go` | 域路由 → `internal/service/*App` |
| `compat_invoke.go` · `bind.go` | 共享绑定辅助 |
| `register_all.go` | 统一注册 |
| `routes_native_gen.go` | `nativeDomainRouteCount = 0` |
| `routes_bridge_gen.go` | swagger **2** 条 |
| `route_stats.go` | `/migration` 口径 |

---

## 存量契约层（只读/生成，非运行时）

| 目录 | 角色 |
|------|------|
| `api/defs/*.api` | goctl 契约分片（`make gen-api`；**勿加新路由**） |
| `api/internal/types/` | goctl HTTP types（compat 引用） |
| `api/internal/handler/doc/` | Swagger 静态页 |
| `api/internal/logic/` | 已退役（`.gitkeep`） |
| `api/internal/*gw/` | 分体/in-process 网关（非 go-zero） |
| `rpc/pb/moe/` | 冻结 message + bridge（无 Super 服务） |
| `rpc/moe.proto` | message-only |
| `scripts/gen/http-routes/fixtures/routes.go` | 路由表归档（gen-http-routes） |

---

## 数据流

```text
HTTP: Client → :8888 moehttp/*_compat → service → biz → data
gRPC: Client → :8080 moegrpc/<domain> → service → biz → data
```

**不经过**：go-zero `rest`、`api/internal/logic`、Super gRPC 服务。

---

## 生成命令

| 场景 | 命令 |
|------|------|
| 域 proto | `make gen` |
| 同步路由表 | `make gen-http-routes` |
| 改存量 defs | `make gen-api` |
| 契约大改 | `make gen-all` |

详见 [scripts/README.md](scripts/README.md)。
