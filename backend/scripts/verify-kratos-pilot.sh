#!/usr/bin/env bash
# 纯 Kratos Phase 0 试点验收
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== build moe-kratos =="
go build -o /dev/null ./cmd/moe-kratos

echo "== pilot sources =="
test -f cmd/moe-kratos/main.go
test -f internal/platform/moekratos/run.go
test -f internal/server/moekratoshttp/register.go
test -f ../docs/dev/kratos-pure-migration-plan.md

echo "== kratos gRPC registration =="
grep -q 'RegisterMoeAdminServer' internal/platform/moekratos/app.go
grep -q 'kratos/v1/moe/runtimes' internal/server/moekratoshttp/register.go

echo ""
echo "OK: kratos pure pilot (phase 0) verification passed"
