# goctl 生成与合并 Logic 说明

> **归档（勿当现状）**：本文描述的 goctl 生成链**已整体移除**。实测 2026-09-08：
> `make gen-api`、`make audit-logic-orphans` 两个 target 已不在 `backend/Makefile`；
> `backend/api/internal/`（logic / handler / types）、`httplegacy/` 目录、`prune-api-logic-*.sh` 脚本均已删除；
> goctl 不再是依赖，Kratos 走 `protoc` + `protoc-gen-go` / `-go-grpc` / `-go-http` / `-openapi`。
> **照本文执行任何命令都会失败。**
>
> **仍然有效的唯一结论**：日常契约改动用 `cd backend && make gen`（域 proto pb/grpc/http + openapi.yaml）；工具版本固定，安装与只读检查见 [new-api-kratos.md](./new-api-kratos.md)。
> **现行 SSOT**：[moe-social-runtime.md](./moe-social-runtime.md) · [new-api-kratos.md](./new-api-kratos.md) · [backend/LAYOUT.md](../../backend/LAYOUT.md)

以下为迁移期历史记录：

## P3 后纪律（历史）

| 事实 | 说明 |
|------|------|
| **logic 层已删除** | `api/internal/logic/` 仅 `.gitkeep` |
| **handler 直调 GW/biz** | 见 `api/internal/handler/README.md` |
| **生产不注册 handler** | `WireOnly=true` → 仅 `httplegacy` + `http_proto` |
| **P5-E** | hybrid handler / `tag-hybrid-routes` 已移除；**无** `//go:build hybrid` 日常构建 |

`make gen-api` 后 **自动**执行：

1. `prune-api-logic-shells.sh`（兼容旧合并文件清单）
2. **`prune-api-logic-retired.sh`** — 删除 goctl 重新生成的全部 `logic/*.go`
3. **`gen-http-routes`** — 同步 `routes_*_gen.go`

## 改存量 HTTP 的推荐顺序

1. **优先**：proto `google.api.http` + `http_proto.go`；存量改 `httplegacy/*_compat.go` + `internal/service`
2. **必须动 defs**：`make gen-api` → **diff handler/**（goctl 可能覆盖）→ 从 git 恢复已迁移 handler
3. **禁止**：把业务写回 `api/internal/logic`

## 命令

```bash
cd backend
make gen-api          # 慎用；自动 prune logic + gen-http-routes
make check
make audit-logic-orphans   # 应为 none
```

日常契约改动优先 **`make gen`**（域 proto + 路由），不跑 goctl api。

## 与 `make gen` 的关系

| 命令 | 跑 goctl api | 影响 logic |
|------|-------------|-----------|
| `make gen` | 否 | 无 |
| `make gen-api` | 是 | 生成后 **立即 prune 清空** |

## 历史：合并 logic 文件（已归档）

P3 前 Admin/User 等使用 `admin_insights_logic.go` 等合并文件 — 已随 logic 层删除。
