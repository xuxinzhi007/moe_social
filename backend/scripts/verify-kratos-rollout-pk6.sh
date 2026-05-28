#!/usr/bin/env bash
# PK-6: GET 路由批量迁 Kratos HTTP（目标 HTTP 覆盖率 ≥40%）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-rollout-pk6 =="

test -f api/moekratospilot/routes_native_gen.go
test -f api/moekratospilot/routes_bridge_gen.go
test -f api/moekratospilot/handler_bridge.go
! test -f api/moekratospilot/routes_handlers_gen.go
! grep -q 'func RegisterGoZeroHTTPHandlers' api/moekratospilot/routes_bridge_gen.go
grep -q 'RegisterNativeDomainHTTPHandlers' api/moekratospilot/register_all.go
grep -q 'RegisterBridgeHTTPHandlers' api/moekratospilot/register_all.go

go test ./api/moekratospilot/... -count=1 -run 'TestHTTPRouteCoverageAtLeast95'

go build -o /dev/null ./cmd/moe-social-stack/...

echo "OK: PK-6 all HTTP routes on Kratos (>=95% route coverage)"
