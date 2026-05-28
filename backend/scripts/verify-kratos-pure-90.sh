#!/usr/bin/env bash
# 完整纯 Kratos 实现度 >= 90%（HTTP 全原生，bridge 仅 swagger）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-pure-90 =="

test -f api/moekratospilot/routes_native_gen.go
test -f api/moekratospilot/routes_bridge_gen.go
grep -q 'wrapNativeHTTP' api/moekratospilot/routes_native_gen.go
! grep -q '/api/posts' api/moekratospilot/routes_bridge_gen.go
! grep -q '/api/auth/' api/moekratospilot/routes_bridge_gen.go
! grep -q '/api/gifts' api/moekratospilot/routes_bridge_gen.go
grep -q '/swagger' api/moekratospilot/routes_bridge_gen.go

go test ./internal/platform/kratosprogress/... -count=1 -run TestCompletePureKratosAtLeast90
go test ./api/moekratospilot/... -count=1

go build -o /dev/null ./cmd/moe-social-stack/...

echo "OK: complete pure Kratos percent >= 90"
