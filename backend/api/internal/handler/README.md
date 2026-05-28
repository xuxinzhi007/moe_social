# api/internal/handler — Hybrid 回滚壳（非生产路径）



> **P3 完成后**：handler **直调** `svc.*GW` / `handlerutil` / `internal/biz`；**无** `api/internal/logic`。  

> **P4-H**：默认构建 **不编译** `routes.go`（见 build tag）。



## 生产（`kratos_pure_enabled: true`）



- `make moe-social` → `WireOnly=true` → **不**调用 `RegisterHandlers`

- 对外 HTTP 仅 `api/moehttp/*_compat.go`（263 条 + swagger bridge 2 条）

- 默认 `go build`：`routes_stub.go`（`//go:build !hybrid`）空实现，**不** import handler 子包



## Hybrid 回滚（`-tags hybrid`）



- 编译时带上 hybrid tag：`go build -tags hybrid ./cmd/moe-social`

- `routes.go`（`//go:build hybrid`）注册全量 go-zero handler

- 配置：`kratos_pure_enabled=false` + `kratos_hybrid_http_fallback=true`



## `make gen-api` 警告



goctl 会 **覆盖** `handler/*.go` 为 logic 委托模板。P3 后改 `api/defs` 时：



1. 优先只改 `types` / `routes` 所需字段，或改 `api/moehttp` compat

2. 若必须 `make gen-api`：gen 后 **禁止**恢复 logic；跑 `prune-api-logic-retired.sh` + `tag-hybrid-routes.sh`；从 git 恢复已迁移的 handler



见 [goctl-generation-hygiene.md](../../../docs/dev/goctl-generation-hygiene.md)。

