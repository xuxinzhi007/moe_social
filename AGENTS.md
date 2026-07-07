# Repository Guidelines

**规则入口**：`.cursor/rules/moe-social-unified.mdc` · **踩坑**：`.cursor/LESSONS.md` · **Review**：`code_review.md`

## Structure

- **Flutter** `lib/pages/<domain>/` + `widgets/` `services/` `providers/`
- **后端** `backend/api/<module>/v1/*.proto` · Kratos `service → biz → data`
- **管理台** `moe-admin/`

## Commands

| 范围 | 命令 |
|------|------|
| Flutter | `flutter pub get` · `flutter analyze` · `flutter test` |
| 后端 | `cd backend && make gen` · `make check` · `make moe-social` · `go test ./...` |
| 管理台 | `cd moe-admin && npm run build` |

Kratos：`docs/dev/kratos-migration-status.md` · OpenAPI：`docs/dev/openapi-apifox.md`

## Skills（`.cursor/skills/`）

`golang-style` · `effective-go` · `implementation-guardrails` · `golang-gin-database` · `git-commit`


# backend目录内执行，生成cover.out
go test ./internal/... -coverpkg=./internal/... -coverprofile=cover.out
# 生成可视化报告
go tool cover -html=cover.out -o coverage.html
