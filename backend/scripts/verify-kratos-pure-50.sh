#!/usr/bin/env bash
# 完整纯 Kratos 实现度 >= 50%（percent，非 rollout）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-pure-50 =="

grep -q 'RegisterNativeDomainHTTPHandlers' api/moekratospilot/register_all.go
test -f api/moekratospilot/routes_native_gen.go
test -f api/moekratospilot/routes_bridge_gen.go
test -f api/moekratospilot/native_bridge.go

go test ./internal/platform/kratosprogress/... -count=1 -run TestCompletePureKratosAtLeast50
go test ./api/moekratospilot/... -count=1

go build -o /dev/null ./cmd/moe-social-stack/...

echo "OK: complete pure Kratos percent >= 50 (see /migration; target 90: make verify-kratos-pure-90)"
