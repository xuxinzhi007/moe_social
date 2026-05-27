# Repository Guidelines

## Use This File as an Entry Point
Keep this file short. If a topic needs detail, put it in a dedicated file and link it here. For this repo, review rules live in `code_review.md`; architecture details belong in `backend/README.md` and `docs/README.md` (doc index last updated 2026-05-27).

## Project Structure
Frontend code is in `lib/`, organized by feature under `lib/pages/<domain>/` with shared code in `models/`, `services/`, `providers/`, `widgets/`, and `utils/`. Flutter tests live in `test/`. Backend code is in `backend/`, with API definitions in `backend/api/super.api`, RPC definitions in `backend/rpc/super.proto`, and Go tests beside packages as `*_test.go`.

## Core Commands
- `flutter pub get`: install Flutter dependencies.
- `flutter analyze`: run Dart and Flutter lint checks.
- `flutter test`: run Flutter tests.
- `cd backend && make gen`: regenerate goctl API/RPC code.
- `cd backend && make build`: build backend binaries.
- `cd backend && go test ./...`: run backend tests.

## Coding Rules
Match existing structure before adding new abstractions. Use `snake_case.dart` filenames, `PascalCase` types, `camelCase` members, and 2-space Dart indentation. Keep UI logic in pages/widgets, shared state in providers, and network or persistence code in services. For Go, keep logic in `internal/logic`, format with `gofmt`, and avoid editing generated files by hand.

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
