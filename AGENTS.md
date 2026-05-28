# Repository Guidelines

## Use This File as an Entry Point
Keep this file short. If a topic needs detail, put it in a dedicated file and link it here. For this repo, review rules live in `code_review.md`; architecture details belong in `backend/README.md` and `docs/README.md` (doc index last updated 2026-05-27).

## Project Structure
Frontend code is in `lib/`, organized by feature under `lib/pages/<domain>/` with shared code in `models/`, `services/`, `providers/`, `widgets/`, and `utils/`. Flutter tests live in `test/`. Backend code is in `backend/`, with HTTP goctl entry `backend/api/moe.api` (shards in `api/defs/`), RPC entry `backend/rpc/moe.proto` (shards in `rpc/defs/`), and Go tests beside packages as `*_test.go`. Run `make moe-social` for single-process HTTP+gRPC.

## Core Commands
- `flutter pub get`: install Flutter dependencies.
- `flutter analyze`: run Dart and Flutter lint checks.
- `flutter test`: run Flutter tests.
- `cd backend && make gen`: regenerate goctl API/RPC code.
- `cd backend && make build`: build backend binaries.
- `cd backend && go test ./...`: run backend tests.

## Coding Rules
Match existing structure before adding new abstractions. Use `snake_case.dart` filenames, `PascalCase` types, `camelCase` members, and 2-space Dart indentation. Keep UI logic in pages/widgets, shared state in providers, and network or persistence code in services. For Go, keep business logic in `internal/biz` (and `internal/service` for orchestration), format with `gofmt`, and avoid editing generated files by hand. Production entry: `cd backend && make moe-social`; see `docs/dev/kratos-migration-status.md`.

## Kratos migration status

**Current / next snapshot**: [docs/dev/kratos-migration-status.md](docs/dev/kratos-migration-status.md) · detail: [docs/dev/kratos-legacy-api-migration.md](docs/dev/kratos-legacy-api-migration.md) §0.

## Large tasks (multi-agent)

For **large, multi-domain** work (e.g. Kratos compat migration across `user` / `admin` / `platform`), do **not** run everything in one serial session. Split by domain, use **parallel subagents** (`Task` tool), and isolate branches with **git worktree**. Rules: [.cursor/rules/parallel-agent-workflow.mdc](.cursor/rules/parallel-agent-workflow.mdc). After merge, update the status doc numbers.

## Agent Long-term Memory
Cross-session knowledge uses layered docs (do not bloat this file):
- **Repeated pitfalls**: [.cursor/LESSONS.md](.cursor/LESSONS.md) — read before coding; add only after the same mistake twice (or one catastrophic miss).
- **Playbook**: [docs/guidelines/agent-long-term-memory.md](docs/guidelines/agent-long-term-memory.md) — layers L0–L3, session close, model-upgrade compression.
- **Session archives**: [docs/guidelines/sessions/](docs/guidelines/sessions/) — copy [_TEMPLATE.md](docs/guidelines/sessions/_TEMPLATE.md) per substantial task; merge stable facts into `docs/dev/` or `docs/product/`.
- **Cursor rule**: `.cursor/rules/agent-memory.mdc` (LESSONS on start, session summary on close).

## Retrospective Rules
Two recurring failure modes are overlong generic docs and stopping at code changes without verification. Avoid both:
- Prefer short, repo-specific instructions over broad templates.
- Define "done" as code changed, checks run, and results reported.
- When detail grows, split it into focused files such as `code_review.md` or architecture notes instead of expanding this file.

## Review and Done Criteria
Use `/review` for PR-style review, uncommitted changes, a specific commit, or a custom review request. If `code_review.md` exists, follow it as the default review standard for this repo.

Before closing any code task, run the relevant checks for touched areas and report the outcome. Minimum expectations:
- Flutter changes: `flutter analyze` and targeted `flutter test`.
- Backend changes: `cd backend && go test ./...` and regenerate/build if contracts changed.
- Doc-only changes: verify links, commands, and scope instead of claiming code tests were run.
