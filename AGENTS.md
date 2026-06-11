# Repository Guidelines

**规则入口**：`.cursor/rules/moe-social-unified.mdc` · **踩坑**：`.cursor/LESSONS.md` · **Review**：`code_review.md`

## Structure

- **Flutter** `lib/pages/<domain>/` + `widgets/` `services/` `providers/`
- **后端** `backend/api/<module>/v1/*.proto` · Kratos `service → biz → data`
- **管理台** `moe-admin/` · **RPA** `moe-auto/`

## Commands

| 范围 | 命令 |
|------|------|
| Flutter | `flutter analyze` · `flutter test` |
| 后端 | `cd backend && make gen` · `make check` · `make moe-social` |
| 管理台 | `cd moe-admin && npm run build` |

Kratos：`docs/dev/kratos-migration-status.md` · OpenAPI：`docs/dev/openapi-apifox.md`

## Skills（`.cursor/skills/`）

`golang-style` · `effective-go` · `implementation-guardrails` · `golang-gin-database` · `git-commit`
