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
| 后端 | `cd backend && make gen` · `make check` · `make moe-social` · `make temp-mail-password EMAIL=foo@web-library.net` · `go test ./...` |
| 管理台 | `cd moe-admin && npm run build` |

Kratos：`docs/dev/kratos-migration-status.md` · OpenAPI：`docs/dev/openapi-apifox.md`

## Skills（`.cursor/skills/`）

**Flutter 统一入口：** `moe-flutter`（产品边界 · 正式架构 · UI · audit） 
Go：`golang-style` · `effective-go` · `implementation-guardrails` · `golang-gin-database` · `git-commit` · `digital-life` · `flame-life-world`（Flame 小世界实验）


# backend目录内执行，生成cover.out
go test ./internal/... -coverpkg=./internal/... -coverprofile=cover.out
# 生成可视化报告
go tool cover -html=cover.out -o coverage.html
