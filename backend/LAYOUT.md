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
api/<domain>/v1/*.pb.go         # make gen-moe-proto

internal/biz/<domain>/          # 业务
internal/data/<domain>/         # 持久化（P4-D；landing 试点）
internal/service/<domain>/      # 应用服务
api/moehttp/                    # Kratos HTTP（*_compat.go 手维护）
internal/server/moekratoshttp/  # /health、/migration
internal/server/moegrpc/        # Kratos gRPC（按需）
internal/platform/moesocial/    # 启动编排
```

**新接口开发手册**：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)  
**存量 compat 清单**：[docs/dev/kratos-legacy-api-migration.md](../docs/dev/kratos-legacy-api-migration.md)

---

## `api/moehttp`（2026-05-27）

| 文件模式 | 作用 |
|----------|------|
| `*_compat.go` | 按域 Kratos 路由；直挂 App/biz |
| `compat_invoke.go` | `invokeLogicJSON` 共享 |
| `register_all.go` | 统一注册入口 |
| `routes_native_gen.go` | **`nativeDomainRouteCount = 0`**（空操作） |
| `routes_bridge_gen.go` | swagger 等 **2** 条 bridge |
| `route_stats.go` | `/migration` 进度口径 |

已删除：`user_logic_compat.go`、`wave2_logic_compat.go`、`platform_logic_compat.go`。

---

## 存量目录（维护老接口，勿扩展新路由）

| 目录 | 角色 |
|------|------|
| `api/defs/*.api` + `api/moe.api` | goctl HTTP 契约（FS-8 分片） |
| `api/internal/handler`、`types` | goctl 生成；**Hybrid 回滚壳**（生产不注册） |
| `api/internal/logic/` | **已退役**（`.gitkeep`） |
| `rpc/` | Super / MoeAdmin goctl gRPC |
| `api/etc/moe.yaml`、`rpc/etc/moe.yaml` | goctl 结构片段，**不是**运行时端口 SSOT |

---

## 数据流

```text
生产:
  Client → :8888 api/moehttp/<domain>_compat.go
         → internal/service/<domain>
         → internal/biz/<domain>
         → internal/data/<domain>（P4 起逐步接入）

gRPC:
  Client → :8080 internal/server/moegrpc 或 rpc/server
         → rpc/logic 或 service → biz
```

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
