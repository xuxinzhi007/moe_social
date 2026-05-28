# Moe Social：go-zero → Kratos 混合迁移方案（完整版）

> **更新：2026-05-28** · **F109 完成** · **F ~98%** · **G ~78%**  
> **总览**：[kratos-migration.md](./kratos-migration.md) · **勾选**：[kratos-migration-status.md](./kratos-migration-status.md) · **路线图**：[kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md)

> 分支：`feat/kratos-hybrid-migration`  
> 目标：**先混合（Kratos 分层 + go-zero 运行时）→ 再纯 Kratos（单进程 + 单契约）**  
> 试点域：**Moe**（Bot 运行时、大脑、流水线、推理观测）

## 1. 背景与问题

| 现状 | 问题 |
|------|------|
| `api/super.api` + `rpc/super.proto` 双契约 | 字段漂移、改一处要跟多处 |
| API logic → `SuperRpcClient` → RPC logic | 双实现、多一跳、难测 |
| goctl 每接口一个 `*_logic.go` | 与 `moe_admin_logic.go` 合并实现冲突（`redeclared`） |
| 业务散在 `rpc/internal/logic` + `pkg/moe` | 域边界不清，拓展成本高 |

## 2. 目标架构（终态）

```text
                    ┌─────────────────────────────────────┐
                    │  cmd/moe-social/main.go (Phase 3)   │
                    │  kratos.App: HTTP + gRPC            │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          ▼                           ▼                           ▼
   transport/http              transport/grpc              conf / middleware
          │                           │
          └─────────────┬─────────────┘
                        ▼
              internal/service/<domain>     ← 协议适配、鉴权参数校验
                        │
                        ▼
              internal/biz/<domain>       ← 纯业务（无 go-zero / 无 gorm 泄漏可选）
                        │
                        ▼
              internal/data/<domain>      ← DB / Redis / 外部依赖
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
     PostgreSQL/MySQL            llama-server (pkg/llminference)
```

**Phase 1～2 过渡态**：HTTP 仍由 `api/super.go`（go-zero rest）监听；RPC 仍由 `rpc/super.go`（zrpc）；**新 Moe 逻辑只写在 `internal/biz|service|data`**，handler/logic 变薄。

## 3. 目录规划

```text
backend/
  api/
    moe/v1/                    # API 版本目录（非「v1 客户端」）
      moe.proto              # Moe 域契约 SSOT
      README.md
    super.api                # legacy，冻结扩张（仅修 bug）
  internal/
    biz/moe/                 # pipeline.go, brain.go, runonce.go
    data/moedata/            # 仓储实现
    service/moe/             # AdminService + 启动时注入的 Deps 工厂
    server/moegrpc/          # moe.v1 gRPC 服务实现
    platform/moewiring/      # 配置、API/RPC 装配
    adapter/                 # RPC 端口适配（rpcsuper）
  api/internal/
    moeadmingw/              # Admin HTTP 三态网关
    moebridge/               # types ↔ biz/proto/super
  rpc/internal/bootstrap/
    moe_admin.go             # WireMoeAdmin
    moe_grpc_register.go     # RegisterMoeGRPC
  rpc/
    internal/logic/          # 变薄：转调 service，super 协议转换
  pkg/moe/                   # 逐步迁入 biz 或保留为 domain 内核
  scripts/
    gen-moe-admin.sh         # legacy goctl 清理
    gen-moe-proto.sh         # Moe proto 生成（Phase 1）
```

## 4. 分阶段实施

### Phase 1 — 混合骨架 ✅ 100%

| 项 | 交付 | 状态 |
|----|------|------|
| 文档 | 本方案 + `kratos-migration-status.md` | ✅ |
| 契约 | `api/moe/v1/moe.proto` | ✅ |
| 分层 | `biz/moe`、`data/moedata`、`service/moe` | ✅ |
| 接线 | **全部** Moe Admin RPC → `MoeAdmin` | ✅ |
| 启动 | `bootstrap.WireMoeAdmin` | ✅ |
| 验收 | `make verify-moe-migration` | ✅ |

**不在 Phase 1**：全仓换 Kratos 启动、User/VIP 迁移、删 `super.api`。

### Phase 2 — 适配层 ✅ 100%

| 项 | 交付 | 状态 |
|----|------|------|
| `internal/adapter/rpcsuper` | Bridge + SuperPort | ✅ |
| `internal/adapter/moeconfig` | 推理 viper 配置 | ✅ |
| 验收脚本 | `scripts/verify-moe-migration.sh` | ✅ |
| API in-process | 可选优化 | 未做（不阻塞） |

### Phase 3 — 纯 Kratos（按月推进）

| 项 | 交付 |
|----|------|
| `cmd/moe-social` | `kratos.New` 统一 HTTP + gRPC |
| `conf.proto` | 配置迁移 |
| 按域迁 proto | `user/v1`、`vip/v1`… |
| 退役 | `goctl api go` 全量 logic、`Super` 巨型 proto 扩张 |

## 5. 代码纪律（强制）

1. **新 Moe / 记忆 / 推理观测**：只改 `api/moe/v1/*.proto`（契约）+ `internal/biz|service|data`。
2. **禁止**对新 Moe 接口执行会生成 `*_logic.go` 空壳的 goctl（`make gen-api` 仅 legacy 模块）。
3. **legacy 修改**：`super.api` / `super.proto` 只修 bug，不新增大功能。
4. **生成后**：`make gen-moe-admin` 或 `go build ./api ./rpc`。
5. **biz 不 import** `rpc/internal/logic`（防循环依赖）。

## 6. 契约策略

| 阶段 | HTTP Admin | gRPC |
|------|------------|------|
| Phase 1 | 仍 `super.api` 路由 | 仍 `super.proto`；logic 内转 proto |
| Phase 2 | 不变或 OpenAPI 从 moe proto 生成文档 | 不变 |
| Phase 3 | grpc-gateway 或 Kratos HTTP 注解 | `api/moe/v1` 直接注册 |

`api/moe/v1/moe.proto` 与 `super.proto` 中 Moe 消息**字段对齐**，迁移期由 logic 做转换，避免客户端改动。

## 7. 测试与验收

- **编译**：`cd backend && go build ./api ./rpc`
- **流水线**：Admin 试跑 → `GET /api/admin/moe/brain/pipeline` 有步骤与 `duration_ms`
- **无回归**：`make gen-moe-admin` 后无 `redeclared`
- **单测（逐步）**：`internal/biz/moe/*_test.go` 对 `ParseRunLog`、流水线空状态

## 8. 风险与回滚

| 风险 | 缓解 |
|------|------|
| 混合期两套标准 | 模块清单 + Cursor 规则 |
| import 循环 | biz ← data；service ← biz；logic ← service |
| 迁移中断 | 按分支交付，Phase 1 可独立上线 |
| 回滚 | 切回 `main`，logic 仍可调回 `runtime` 直调 |

## 9. 相关文档

- [架构说明（当前）](../../backend/架构说明.md)
- [迁移进度清单](./kratos-migration-status.md)
- [Codex 启动指南-后端](../guidelines/Codex启动指南-后端.md)
