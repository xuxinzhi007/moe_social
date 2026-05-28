# backend/scripts

## 新接口（Kratos）— 先看这个

**不要**只跑 `make gen` 就期望出现 handler/logic。  
新能力：`api/<domain>/v1/*.proto` → **`make gen`**（pb）→ `internal/service` + `api/moehttp` 注册。

完整步骤：[docs/dev/new-api-kratos.md](../docs/dev/new-api-kratos.md)  
目录说明：[LAYOUT.md](../LAYOUT.md)

## 生成命令

| 命令 | 用途 |
|------|------|
| `make gen` | 安全：域 proto pb + conf + 同步 `routes_*_gen`（**不**跑 goctl api/rpc） |
| `make gen-api` | **仅存量**：改了 `api/defs/*.api` |
| `make gen-rpc` | 改了 `rpc` 契约 |
| `make gen-all` | defs + rpc + proto 一起改 |
| `make check` | 编译 + 核心单测 |

## 覆盖范围

| 命令 | 会覆盖 | 不会动 |
|------|--------|--------|
| `make gen` | `api/**/v1/*.pb.go`、`api/moehttp/routes_*_gen.go` | `internal/service`、`internal/biz`、`*_compat.go`、logic |
| `make gen-api` | handler、types、routes.go | 已有 `*logic.go` 实现（通常） |

若 `api/defs` 比 `routes.go` 新，`stale-api-hint` 会提示执行 `make gen-api`。

## 目录

```text
scripts/gen/
  moe-proto.sh / moe-conf.sh
  http-routes/     → api/moehttp/routes_*_gen.go
  api-guard.sh     # gen-api 提示
  stale-api-hint.sh
```
