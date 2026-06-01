# goctl 生成与合并 Logic 说明

> **更新：2026-05-29**（P5-E 后无 hybrid 构建）

## P3 后纪律（必读）

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
