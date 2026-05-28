#!/usr/bin/env bash
# PK-4: moe-social Kratos HTTP front + go-zero internal fallback.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-kratos-rollout-pk4 =="

test -f internal/platform/moesocial/kratos_front.go
test -f api/runserver/result.go
grep -q 'StartWithResult' api/runserver/server.go
grep -q 'InternalHTTPPort' api/runserver/server.go
grep -q 'KratosHTTPFrontEnabled' internal/platform/moewiring/config.go
grep -q 'kratos_http_front_enabled' config/config.yaml
grep -q 'kratos_internal_http_port' config/config.yaml
grep -q 'kratos_http_front_enabled' internal/conf/moe/v1/pilot.proto
grep -q 'kratos_internal_http_port' internal/conf/moe/v1/pilot.proto
grep -q 'RegisterAll' internal/platform/moekratos/app.go
grep -q 'RegisterAll' internal/platform/moesocial/kratos_front.go

go test ./internal/platform/kratosprogress/... -count=1 -run TestRolloutPercent
go test ./api/moekratospilot/... -count=1

go build -o /dev/null ./cmd/moe-social-stack

echo "OK: PK-4 Kratos HTTP front (opt-in via moe.kratos_http_front_enabled)"
