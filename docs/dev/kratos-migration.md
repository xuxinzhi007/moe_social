# Kratos 后端架构（SSOT）

> **更新：2026-05-27**  
> **当前阶段**：**纯 Kratos 生产**（`kratos_pure_enabled: true`）· 单进程 `make moe-social` · HTTP `:8888` + gRPC `:8080`

| 文档 | 用途 |
|------|------|
| 本文 | 架构、目录、命令 |
| [kratos-migration-status.md](./kratos-migration-status.md) | 进度勾选 |
| [new-api-kratos.md](./new-api-kratos.md) | **新接口开发**（必读） |
| [moe-social-runtime.md](./moe-social-runtime.md) | 启动与配置 |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | 仓库目录 |
| [../../backend/scripts/README.md](../../backend/scripts/README.md) | `make gen` / `gen-api` |

---

## 1. 当前阶段（一句话）

- **运行时**：Kratos 传输层对外；**一个进程** `cmd/moe-social`，配置 SSOT 为 `backend/config/config.yaml`。
- **业务**：`internal/biz` + `internal/service`；存量 HTTP 仍经 `api/internal/logic` + `*gw` 桥接。
- **契约**：存量 `api/defs/*.api`（goctl）；**新接口**只加 `api/<domain>/v1/*.proto`。
- **验收**：`make check` + `curl /migration`；**已移除** `scripts/verify/*` 与 Makefile `verify-*`。

`make moe-kratos`（:1903x）与 `make verify-*` **已废弃**，勿再写入新文档。

---

## 2. 架构图

```text
  Client (:8888 / :8080)
        │
        ▼
  internal/platform/moesocial     # 启动编排
        │
        ├─ Kratos HTTP :8888
        │    ├─ internal/server/moekratoshttp   (/health, /migration)
        │    └─ api/moehttp                     (compat + routes_*_gen → logic)
        │
        └─ Kratos gRPC :8080
             ├─ internal/server/moegrpc
             └─ rpc/ (Super / MoeAdmin logic)

  业务：internal/service/<domain> → internal/biz/<domain> → MySQL
```

---

## 3. 目录纪律（Kratos / core-platform 对齐）

| 路径 | 角色 |
|------|------|
| `cmd/moe-social/` | 生产入口 |
| `config/config.yaml` | 运行时 SSOT |
| `api/<domain>/v1/*.proto` | **新** HTTP/gRPC 契约 |
| `internal/biz/<domain>/` | 业务 |
| `internal/service/<domain>/` | 应用服务 |
| `api/moehttp/` | Kratos HTTP 注册 |
| `internal/server/moekratoshttp/` | 健康检查、迁移进度 |
| `internal/server/moegrpc/` | Kratos gRPC |

**存量（维护老接口，勿为新能力扩展）**：

| 路径 | 角色 |
|------|------|
| `api/defs/*.api` | goctl HTTP 契约分片 |
| `api/internal/handler|logic|types` | goctl 生成 + 实现 |
| `rpc/` | goctl gRPC + Super |

---

## 4. 常用命令

```bash
cd backend

make moe-social          # 生产单进程
make moe-social-stop     # 释放端口
make check               # 编译 + 核心单测

make gen                 # 安全：域 proto pb + Kratos 路由同步
make gen-api             # 仅当改了 api/defs（存量 HTTP）
make gen-rpc             # 改了 rpc 契约
make gen-all             # defs + rpc + proto 都改

curl -s http://127.0.0.1:8888/migration | jq .
```

---

## 5. 新接口 vs 存量接口

| 场景 | 契约 | 生成 | 实现 |
|------|------|------|------|
| **新 HTTP 能力** | `api/<domain>/v1/*.proto` | `make gen` | `internal/service` + `api/moehttp/*_compat.go` |
| **改老 HTTP** | `api/defs/*.api` | `make gen-api` | `api/internal/logic/*logic.go` |
| **改 gRPC** | `rpc/defs` / `moe.proto` | `make gen-rpc` | `rpc/internal/logic` 或 `internal/service` |

详见 [new-api-kratos.md](./new-api-kratos.md)。

---

## 6. 配置要点（`config/config.yaml`）

| 键 | 生产典型值 | 说明 |
|----|------------|------|
| `moe.kratos_pure_enabled` | `true` | 纯 Kratos HTTP，无 go-zero rest 对外 |
| `moe.kratos_pk8_goctl_retired` | `true` | 日常 `make gen` 不跑 goctl api |
| `moe.kratos_grpc_managed` | `true` | gRPC 由 Kratos 生命周期管理 |
| `runtime.http.port` | `8888` | 对外 HTTP |
| `runtime.grpc.port` | `8080` | 对外 gRPC |

灰度开关（`kratos_admin_http_enabled` 等）用于 **:19032 试点转发**，纯 Kratos 生产下通常保持 `false`。

---

## 7. 历史文档

PK / F / FS 冲刺与 `make verify-*` 手册已迁入 [../archive/dev/kratos/](../archive/dev/kratos/)，仅供查阅，不作执行依据。
