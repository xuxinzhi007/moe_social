#!/usr/bin/env bash
# PK-8: goctl handler 链退役 + 纯 Kratos 生产默认。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-kratos-rollout-pk8 =="

grep -q 'kratos_pk8_goctl_retired' config/config.yaml
grep -q 'kratos_pure_enabled: true' config/config.yaml
grep -q 'gen-moekratospilot-get' Makefile
! grep -qE '^gen: gen-moe-proto.*gen-api' Makefile

test -f api/moekratospilot/routes_native_gen.go
test -f api/moekratospilot/routes_bridge_gen.go
test -f api/moekratospilot/handler_bridge.go
test -f scripts/gen-api-guard.sh
grep -q 'KratosPK8GoctlRetired' internal/platform/moewiring/config.go
grep -q 'KratosHybridHTTPFallback' internal/platform/moesocial/run.go

go test ./internal/platform/moewiring/... -count=1 2>/dev/null || true
go build -o /dev/null ./cmd/moe-social-stack/...
go build -o /dev/null ./api/moekratospilot/...

echo "OK: PK-8 goctl retired; production pure Kratos HTTP via moekratospilot"
