# Code Review Guide

## When to Use `/review`
Use `/review` in four cases:
- Compare a feature branch against its base branch for PR-style review.
- Review uncommitted local changes.
- Review a specific commit.
- Run a custom review with extra instructions.

## Review Priorities
Findings come first. Focus on:
- Behavioral regressions.
- Contract mismatches between Flutter models/services and backend API or RPC definitions.
- Missing verification for changed code paths.
- Risky edits to generated Go files or missing `make gen` after contract changes.
- UI changes that break existing feature/domain structure in `lib/pages/<domain>/`.

## Expected Review Output
Report issues before summaries. For each finding, include:
- Severity.
- File and line reference.
- Why it is a real risk.
- What validation is missing or what change is needed.

If no findings are found, say that explicitly and list residual risks or testing gaps.

## Repo-Specific Checks
- Flutter: check `flutter analyze`, relevant `flutter test`, state handling, and whether logic was misplaced into pages instead of services/providers.
- Backend: check `backend/api/super.api`, `backend/rpc/super.proto`, generated artifacts, `go test ./...`, and separation between handler and logic layers.
- Docs: reject long generic guidance when a short repo-specific rule or a linked doc would be clearer.
