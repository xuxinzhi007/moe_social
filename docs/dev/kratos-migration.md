# Kratos 后端架构（SSOT）

> **更新：2026-05-27（P0/P1 收口）**  
> **当前阶段**：**纯 Kratos 生产** · **P0–P6 + P0/P1 审计完成** · `make moe-social` · HTTP `:8888` + gRPC `:8080`

| 文档 | 用途 |
|------|------|
| 本文 | 架构、目录、命令 |
| [kratos-migration-status.md](./kratos-migration-status.md) | **当前 / 下一步** |
| [kratos-p6-defs-to-proto.md](./kratos-p6-defs-to-proto.md) | P6 契约 |
| [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) | 存量 compat 清单 |
| [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) | **Next** 分体 api/rpc |
| [grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md) | 域 gRPC 冒烟 |
| [parallel-agent-workflow.md](../guidelines/parallel-agent-workflow.md) | 大任务多 Agent |
| [new-api-kratos.md](./new-api-kratos.md) | **新接口开发**（必读） |
| [moe-social-runtime.md](./moe-social-runtime.md) | 启动与配置 |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | 仓库目录 |
| [../../backend/scripts/README.md](../../backend/scripts/README.md) | `make gen` / `gen-api` |

P4/P5 阶段专文 → [../archive/dev/kratos/](../archive/dev/kratos/)（`docs/dev/kratos-p4-*`、`kratos-p5-*` 为 stub）

---

## 1. 当前阶段（一句话）

- **运行时**：Kratos 传输层对外；**一个进程** `cmd/moe-social`，配置 SSOT 为 `backend/config/config.yaml`。
- **HTTP**：**227** 条 proto 路由（`http_proto.go`）+ **45** 条 compat 余量（`httplegacy`）；双信封（`http_envelope.go` + `compat_envelope.go`）。
- **gRPC**：12 域独立服务 + `MoeAdmin`；**无** `service Super`（P5-B）。
- **契约**：新接口只加 `api/<domain>/v1/*.proto`；存量 `api/defs` 仅维护，日常 `make gen` 不跑 goctl api。
- **go-zero**：生产 `moe-social` **依赖树零 go-zero**（P5-D）；紧急回滚 `go build -tags hybrid`。
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
        │    ├─ internal/server/http.go         (CORS + 信封 Filter)
        │    ├─ internal/server/http_proto.go   (Register*HTTPServer · 227 路由)
        │    └─ internal/server/httplegacy/       (compat 45 条)
        │
        └─ Kratos gRPC :8080
             ├─ internal/server/grpc/      # 12 域 + MoeAdmin
             └─ rpc/internal/bootstrap/    # MoeAdmin / Bot 装配

  业务：internal/server/grpc/<domain> → internal/service/<domain> → internal/biz → MySQL
```

---

## 3. 目录纪律（Kratos / core-platform 对齐）

| 路径 | 角色 |
|------|------|
| `cmd/moe-social/` | 生产入口 |
| `config/config.yaml` | 运行时 SSOT |
| `api/<domain>/v1/*.proto` + `*_http.pb.go` | **新** HTTP/gRPC 契约 |
| `internal/biz/<domain>/` | 业务 |
| `internal/service/<domain>/` | 应用服务 |
| `internal/server/http_proto.go` | **官方** HTTP 注册（19 次 Register） |
| `internal/server/compat_envelope.go` | Compat JSON 压平（P0） |
| `internal/server/httplegacy/` | 存量 compat（**45** 条活跃） |
| `internal/server/http.go` | 健康检查、迁移进度 |
| `internal/server/grpc/` | Kratos gRPC |
| `internal/platform/{svc,wiring,moesocial}/` | 装配与启动 |

**存量 / 回滚（默认构建不编译）**：

| 路径 | 角色 |
|------|------|
| `api/defs/*.api` | 存量 HTTP 契约（慎改；`make gen-api`） |
| `internal/legacy/types/` | goctl JSON types |
| `internal/apilegacy/` | 原 gw/common（过渡） |
| `api/internal/handler/**` | hybrid 残留 |
| `rpc/moe.proto` | message-only（无 `service Super`） |

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
| **新 HTTP 能力** | `api/<domain>/v1/*.proto` + `google.api.http` | `make gen` | `internal/service` + `http_proto.go` |
| **改老 HTTP** | `api/defs/*.api` | `make gen-api`（慎用） | `httplegacy` + `internal/service` |
| **改 gRPC** | `api/<domain>/v1/*.proto` | `make gen` | `internal/server/grpc` + `internal/service` |

详见 [new-api-kratos.md](./new-api-kratos.md)。

---

## 6. 配置要点（`config/config.yaml`）

| 键 | 生产典型值 | 说明 |
|----|------------|------|
| `moe.kratos_pure_enabled` | `true` | 纯 Kratos HTTP，无 go-zero rest 对外 |
| `moe.single_process` | `true` | 单进程 `moe-social` |
| `moe.super_grpc_retired` | `true` | 不注册 Super、API 无 Super 回环 |
| `moe.kratos_super_grpc_native` | `true` | gRPC 用 kratos/transport（非 zrpc） |
| `moe.kratos_pk8_goctl_retired` | `true` | 日常 `make gen` 不跑 goctl api |
| `runtime.http.port` | `8888` | 对外 HTTP |
| `runtime.grpc.port` | `8080` | 对外 gRPC |

灰度开关（`kratos_admin_http_enabled` 等）用于 **:19032 试点转发**，纯 Kratos 生产下通常保持 `false`。

---

## 7. 历史文档

PK / F / FS 冲刺与 `make verify-*` 手册已迁入 [../archive/dev/kratos/](../archive/dev/kratos/)，仅供查阅，不作执行依据。
