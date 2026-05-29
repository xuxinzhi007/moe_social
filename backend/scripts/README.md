# backend/scripts

## 新接口（Kratos）— 先看这个

**不要**只跑 `make gen` 就期望出现 handler/logic。  
新能力：`api/<domain>/v1/*.proto` → **`make gen`**（pb）→ `internal/service` + `api/moehttp` 注册。

完整步骤：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)  
目录说明：[LAYOUT.md](../LAYOUT.md)

## 生成命令

| 命令 | 用途 |
|------|------|
| `make gen` | 安全：域 proto pb + conf + 同步 `routes_*_gen`（**不**跑 goctl api/rpc）；`native_gen` 应为 0 |
| `make gen-http-routes` | 仅同步 `api/moehttp/routes_*_gen.go` |
| `make gen-moe-proto` | 仅 `api/*/v1/*.proto` → `*.pb.go` |
| `make gen-api` | 改 `api/defs` 后；**自动 prune** 删除与合并 logic 重复的空壳 |
| `make gen-rpc` | 组装 message-only `rpc/moe.proto`（无 Super service） |
| `make gen-all` | defs + rpc + proto 一起改 |
| `make gen-moe-admin` | Admin 相关 defs 变更后 |
| `make check` | 编译 + 核心单测 |
| `make audit-logic-orphans` | P3：列出无 handler 引用的 logic 文件 |
| `make grpc-smoke` | notify/chat/vip gRPC 冒烟 |
| `make split-deploy-smoke` | 分体 api/rpc 构建 + 联调 |

## 覆盖范围

| 命令 | 会覆盖 | 不会动 |
|------|--------|--------|
| `make gen` | `api/**/v1/*.pb.go`、`api/moehttp/routes_*_gen.go` | `internal/service`、`internal/biz`、`*_compat.go`、logic |
| `make gen-api` | handler、types、routes.go；删 todo 重复壳 | **合并 `*_logic.go`** 中的手写实现 |

合并 Logic 说明：[docs/dev/goctl-generation-hygiene.md](../docs/dev/goctl-generation-hygiene.md)

若 `api/defs` 比 `routes.go` 新，`stale-api-hint` 会提示执行 `make gen-api`。

## 活跃目录

```text
scripts/gen/
  moe-proto.sh / moe-conf.sh / moe-admin.sh
  http-routes/          → api/moehttp/routes_*_gen.go
  fs8-assemble-rpc-proto.py
  p6_mark_defs.py       # 改 api/defs 后可选重跑 P6-C 标注
  api-guard.sh / stale-api-hint.sh / post-gen-check.sh
  prune-api-logic-*.sh
scripts/tools/logic-orphan-audit/
scripts/grpc-smoke-notify-chat-vip.sh
scripts/split-deploy-smoke.sh
```

## 已归档（勿日常运行）

P4–P6 一次性迁移脚本 → [archive/README.md](./archive/README.md)

`make remove-hybrid-gozero`、`make fs8-split-api`、`make gen-rpc-legacy` 等 target 已 **DEPRECATED**（P5-E 已执行）。
