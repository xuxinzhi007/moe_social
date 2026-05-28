# P5 — Super 退役与「代码库零 go-zero」

> **最后更新：2026-05-28**  
> **前置**：P4 完成（data 20/21 · 独立 gRPC 12/12 · compat HTTP 263）

---

## 目标

| 层级 | 含义 | DoD |
|------|------|-----|
| **P5-A 运行时** | 单进程生产不再依赖 Super gRPC | `super_grpc_retired=true` + `single_process=true` → 不注册 Super、API 不 dial zrpc |
| **P5-B 代码库** | 删除 `rpc/internal/logic/*` goctl 层 | ✅ baseline **209** → **0** |
| **P5-C gateway** | API 网关无 Super 回退 | ✅ `*gw` + `svc` 无 `SuperClient` |
| **P5-D 零 go-zero 生产** | `moe-social` 依赖树无 go-zero | ✅ 见 [kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) |

**P5-B（2026-05-28）**：`rpc/internal/logic` 已整目录删除（209 文件）；`superserver.go` 已删；`moe.proto` 仅保留 `import defs/common.proto`（无 `service Super`）。MoeAdmin/Bot 依赖迁至 `rpc/internal/bootstrap/*`。

**P5-C（2026-05-28）**：`api/internal/*gw` 已移除 `moe.SuperClient`；分体 `grpcclient.Dial` MoeAdmin。

**P5-D（2026-05-28）**：默认构建 `go list -deps ./cmd/moe-social` 无 `go-zero`；`moehttp` 用 Kratos Bind；legacy handler/websocket 仅 `hybrid` 标签。

**文档**：[kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) · [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) · [grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md)

---

## 配置（SSOT）

`backend/config/config.yaml`：

```yaml
moe:
  single_process: true          # make moe-social
  super_grpc_retired: true      # P5-A；分体 api/rpc 容器部署时设为 false
  kratos_pure_enabled: true
  kratos_super_grpc_native: true
  # 全部 *_api_in_process: true（HTTP 网关无 Super fallback）
```

**生效条件**（`moewiring.SuperGrpcRetired()`）：

1. `moe.super_grpc_retired: true`
2. `moe.single_process: true`（防止分体部署误关 Super 回环）

---

## P5-A / P5-B 已实现

| 组件 | 行为 |
|------|------|
| `rpc/runserver/kratos.go` | 不再 `RegisterSuperServer` |
| `rpc/internal/server/superserver.go` | **已删除** |
| `rpc/internal/logic/` | **已删除**（209 文件） |
| `rpc/moe.proto` | **无 `service Super`**（message-only） |
| `scripts/gen/fs8-assemble-rpc-proto.py` | 仅组装 common import |
| `rpc/internal/bootstrap/moe_admin_wire.go` | MoeAdmin + Bot 调度 |
| `rpc/internal/bootstrap/app_bridge.go` | SuperPort → Post/LLM App |
| `api/internal/svc/servicecontext.go` | 单进程不 zrpc；分体 zrpc → **MoeAdmin**（无 SuperClient） |
| `api/internal/*gw`（23 包） | 无 `moe.SuperClient`；进程内 / `gwutil.ErrUnavailable` |
| `internal/platform/moewiring/app_adapter.go` | Post/LLM App 实现 `SuperPort`（7 方法；不可放 pkg/port，会 import cycle） |
| `moewiring.NewAPIAdminService(client, appPort)` | 单进程用 AppAdapter，分体用 gRPCAdapter |
| `api/runserver/server.go` | Post/LLM 装配后再 init MoeAdmin |

**RPC 侧 MoeAdmin**：通过 `bootstrap/app_bridge` → `moewiring.NewAppAdapter(PostApp, LLMApp)`；Bot 调度在 `bootstrap/moe_admin_wire.go`。

---

## 迁移顺序（P5-B 建议）

```mermaid
flowchart LR
  A[P5-A 运行时退役] --> B[按域删 logic 文件]
  B --> C[归档 super.proto / superserver.go]
  C --> D[移除 go-zero 依赖]
```

1. **已独立 gRPC 的域**（post/user/comment/…）：删对应 `rpc/internal/logic/*`，HTTP/RPC 走 `internal/service`
2. **仍经 Super 的 Admin RPC**：迁到 `moe.v1.MoeAdmin` 或 HTTP compat
3. **客户端**：Flutter / moe-admin 确认无 `Super.*` 直连（当前全走 HTTP compat）
4. **分体部署**：保持 `super_grpc_retired=false` 直至 api/rpc 容器均完成 in-process 或域 gRPC

---

## 进度指标（/migration）

| breakdown 键 | 含义 |
|--------------|------|
| `p5_super_runtime_pct` | P5-A：100 = Super 已退役 |
| `super_grpc_retired_pct` | 同上 |
| `rpc_logic_files_left` | 剩余 Super logic 文件数 |
| `rpc_logic_retired_pct` | 相对 baseline 209 的删除比例 |

---

## 验收

```bash
cd backend
go build ./api ./rpc ./cmd/moe-social
go test ./internal/platform/kratosprogress/... -count=1

# 启动后（需 DB）
curl -s http://127.0.0.1:8888/migration | jq '.breakdown | {p5: .p5_super_runtime_pct, rpc_left: .rpc_logic_files_left}'
# 期望：p5=100, rpc_left=0, rpc_logic_retired_pct=100
```

---

## 回滚

```yaml
moe:
  super_grpc_retired: false
  # 或
  single_process: false
```

重启 `make moe-social` → Super 重新注册、API 恢复 zrpc 回环。

---

## 相关文档

- [kratos-migration-status.md](./kratos-migration-status.md) — 总状态板
- [kratos-p4-post-migration.md](./kratos-p4-post-migration.md) — P4 SSOT
- [new-api-kratos.md](./new-api-kratos.md) — 新 API 纪律
