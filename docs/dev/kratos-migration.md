# Kratos 混合迁移 → Moe 域完整交付（SSOT）

> **迁移类型**：先 **Hybrid（分层 + go-zero 运行时）**，Moe 域现已支持 **单进程终态入口** `cmd/moe-social`。  
> **Moe 域进度：100%**（分层、gRPC 契约、Admin 网关、单进程启动均已交付）。  
> **全仓进度**：User/VIP 等仍走 `super.api` / `super.proto`（约 30% 待后续域迁移）。  
> 勾选：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 三种运行方式

| 方式 | 命令 | 进程数 | 说明 |
|------|------|--------|------|
| **推荐·单进程** | `make moe-social` | **1 个进程、2 个端口** | HTTP `:8888` + gRPC `:8080`（与 `make dev` 相同端口，只合并进程） |
| 经典双进程 | `make dev` / `make rpc` + `make api` | 2 | 与历史一致 |
| 观测壳 | `make moe-platform` | 1 | 仅 `:19020` health/migration，非业务 |

单进程启动日志（**8888 只出现一次**；**8080 是 gRPC，不是第二个 8888**）：

```text
Starting rpc server at 0.0.0.0:8080 ...
Starting server at 0.0.0.0:8888 ...
moe-social: 单进程已就绪（非单端口）— gRPC 127.0.0.1:8080 + HTTP 127.0.0.1:8888
moe admin gateway route: in_process
```

若要「对外只暴露一个端口」，需后续用 grpc-gateway / 纯 Kratos HTTP 合并路由（全仓迁移阶段），当前 Moe 域仍沿用 go-zero 双监听设计。

---

## 2. 进度统计

| 指标 | % | 说明 |
|------|---|------|
| **Moe 域（本迁移范围）** | **100%** | 见下表 |
| Moe 业务分层 | 100% | biz / service / data |
| Moe proto + moegrpc | 100% | `moe.proto` + RPC 注册 |
| Admin MoeGW | 100% | 11 个 HTTP logic |
| 单进程 `moe-social` | 100% | `make verify-moe-complete` |
| 全仓退役 super 双契约 | ~30% | User/VIP/社交未迁 |

---

## 3. 终态框架（单进程）

```text
                    ┌──────────────────────────────────────────┐
                    │  cmd/moe-social  (kratos.App)            │
                    │  ├─ goroutine: zrpc :8080                │
                    │  │    super.Super + moegrpc.MoeAdmin     │
                    │  └─ kratos: rest :8888 (go-zero)         │
                    └──────────────────┬───────────────────────┘
                                       │
                         moe-admin ──HTTP──► Admin Moe 路由
                                       │
                                       ▼
                         api/internal/moeadmingw.Gateway
                              └─ in_process → MoeAdmin
                                       │
                                       ▼
                         internal/service/moe → biz → data
                                       │
                                       ▼
                              MySQL + llama-server
```

---

## 4. 目录结构树

```text
backend/
├── cmd/
│   ├── moe-social/              # ★ 单进程推荐入口（100% 交付）
│   └── moe-platform/            # Kratos 观测（health/migration）
├── api/
│   ├── super.api                # legacy HTTP（全站，含非 Moe）
│   ├── super.go                 # 仅 API 进程入口
│   ├── runserver/               # API 启动逻辑（供 moe-social 复用）
│   ├── moe/v1/moe.proto         # Moe 契约 SSOT
│   └── internal/
│       ├── moeadmingw/         # Admin Moe 三态网关
│       ├── moebridge/
│       └── logic/admin/*moe*
├── rpc/
│   ├── super.proto              # legacy RPC（全站）
│   ├── super.go                 # 仅 RPC 进程入口
│   ├── runserver/               # RPC 启动逻辑（供 moe-social 复用）
│   └── internal/bootstrap/
│       ├── moe_admin.go
│       └── moe_grpc_register.go
├── internal/
│   ├── biz/moe/
│   ├── data/moedata/
│   ├── service/moe/
│   ├── server/moegrpc/
│   └── platform/
│       ├── moewiring/
│       └── moesocial/           # 单进程编排
└── scripts/
    ├── verify-moe-migration.sh
    ├── verify-moe-grpc.sh
    ├── verify-moe-gateway.sh
    └── verify-moe-complete.sh   # ★ 100% 一键验收
```

---

## 5. 配置（`config.yaml` → `moe`）

| 键 | 推荐 | 含义 |
|----|------|------|
| `api_in_process` | `true` | Admin Moe 进程内 MoeAdmin |
| `register_moe_grpc` | `true` | RPC 注册 `moe.v1.MoeAdmin` |
| `use_moe_grpc` | `true` | 无 in-process 时走 moe gRPC |
| `single_process` | `make moe-social` 时可设 `true` | 标记单进程模式（文档/观测） |

---

## 6. 验收（100%）

```bash
cd backend
make verify-moe-complete    # 含 migration + grpc + gateway + moe-social 编译

# 运行（单进程）
make moe-social
# 或双进程：make dev
```

管理台联调：`moe-admin` + llama-server `:6633` + `make migrate-moe`（缺表时）。

---

## 7. 相关文档

| 文件 | 用途 |
|------|------|
| [kratos-hybrid-migration-plan.md](./kratos-hybrid-migration-plan.md) | Phase 1+2 纪律 |
| [kratos-phase3-roadmap.md](./kratos-phase3-roadmap.md) | 全仓纯 Kratos 后续 |
| [kratos-migration-status.md](./kratos-migration-status.md) | 勾选清单 |
