#!/usr/bin/env bash
# 完整纯 Kratos 实现度 >= 80%（moe-social :8888/migration percent）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-pure-80 =="

grep -q 'kratos_pure_enabled: true' config/config.yaml
grep -q 'RegisterNativeDomainHTTPHandlers' api/moekratospilot/register_all.go
grep -q 'runWithKratosGRPC' internal/platform/moesocial/run.go
test -f rpc/runserver/kratos.go

go test ./internal/platform/kratosprogress/... -count=1 -run 'TestCompletePureKratosAtLeast80|TestRolloutPercentAtLeast80'
go test ./api/moekratospilot/... -count=1
go build -o /dev/null ./cmd/moe-social-stack/...

echo "OK: complete pure Kratos percent >= 80 (see :8888/migration)"
