# api/internal/handler — 生产壳（非业务路径）

> **P5-E 后**：hybrid go-zero handler 已删除；生产 HTTP 仅 `api/moehttp/*_compat.go`。

## 生产（`make moe-social`）

- `routes_stub.go`（`//go:build !hybrid`）空实现 `RegisterHandlers`
- 对外 HTTP：`api/moehttp/*_compat.go`（263 条 + swagger bridge 2 条）
- Swagger：`api/internal/handler/doc/`（经 `routes_bridge_gen.go` 注册）

## 路由生成 SSOT

- 历史 goctl 路由表归档：`scripts/gen/http-routes/fixtures/routes.go`
- 生成命令：`make gen-http-routes`

## 勿再扩展

- 新接口见 `docs/dev/new-api-kratos.md`（域 proto + `moehttp` compat）
- `make gen-legacy-goctl` 仍会 goctl 生成 types/handler，但 **无** hybrid 回滚路径
