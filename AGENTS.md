# Repository Guidelines

**规则入口**：`.cursor/rules/moe-social-engineering.mdc`（工程规则 SSOT）· `.cursor/rules/moe-social-unified.mdc` · **踩坑**：`.cursor/LESSONS.md` · **Review**：`code_review.md`

## Structure

- **Flutter** `lib/pages/<domain>/` + `widgets/` `services/` `providers/`
- **后端** `backend/api/<module>/v1/*.proto` · Kratos `service → biz → data`
- **管理台** `moe-admin/`

## Commands

| 范围 | 命令 |
|------|------|
| Flutter | `flutter pub get` · `flutter analyze` · `flutter test` |
| 后端 | `cd backend && make gen` · `make check` · `make test` · `make test-race` · `make moe-social` · `make temp-mail-password EMAIL=foo@web-library.net` |
| 管理台 | `cd moe-admin && npm run build` |

Kratos：`docs/dev/kratos-migration-status.md` · OpenAPI：`docs/dev/openapi-apifox.md`

## Skills（`.cursor/skills/`）

**入口：** `moe-skill`（通用质量规则，对任意改动生效，按整条链路看，不按功能点分叉）


# backend目录内执行，生成cover.out
# CGO_ENABLED=1 必须显式给：本机 go env 里它持久为 0，而 gorm 的 sqlite 驱动依赖 cgo。
# 关掉它时所有 DB 用例会静默 t.Skip，go test 照样报 ok、cover.out 照样生成，
# 只是这些路径全被算成「未覆盖」而没有任何报错 —— 覆盖率报告会安静地骗你。
CGO_ENABLED=1 go test ./internal/... -coverpkg=./internal/... -coverprofile=cover.out
# 生成可视化报告
go tool cover -html=cover.out -o coverage.html

# 同理，不要用裸 `go test ./...` 当门禁。用 `make test`（已写死 CGO_ENABLED=1）；
# `backend/utils/cgo_canary_test.go` 是配套哨兵，CGO 关闭时它会直接失败并提示正确命令。
