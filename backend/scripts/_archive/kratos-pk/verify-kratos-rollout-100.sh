#!/usr/bin/env bash
# PK-9 铺轨 100%：纯 Kratos 传输生产路径（rollout_percent；完整实现见 percent）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-rollout-100 =="

test -f internal/platform/moesocial/kratos_pure_http.go
grep -q 'KratosPureEnabled' internal/platform/moewiring/config.go
grep -q 'kratos_pure_enabled' config/config.yaml
grep -q 'WireOnly' api/runserver/server.go

bash scripts/verify-kratos-rollout-pk34.sh

go test ./internal/platform/kratosprogress/... -count=1 -run 'TestRolloutPercentAtLeast100WhenPure|TestCompletePureKratosAtLeast100'

go build -o /dev/null ./internal/platform/moesocial/ ./api/moekratospilot/ ./api/runserver/

echo "OK: rollout_percent=100 (transport PK-9); complete pure kratos percent in /migration"
