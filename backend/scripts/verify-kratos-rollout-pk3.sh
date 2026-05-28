#!/usr/bin/env bash
# PK-3: 多域 Kratos HTTP（Insights + Admin RO + LLM read）+ RegisterAll。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-kratos-rollout-pk3 =="

test -f api/moekratospilot/register_all.go
test -f api/moekratospilot/deps.go
test -f api/moekratospilot/admin_insights_compat.go
test -f api/moekratospilot/admin_readonly_compat.go
test -f api/moekratospilot/llm_read_compat.go
test -f api/internal/admingw/kratos_client.go
test -f api/internal/admingw/gateway_factory.go
test -f internal/platform/kratosprogress/report.go

grep -q 'kratos_admin_insights_http_enabled' config/config.yaml
grep -q 'KratosAdminInsightsHTTPEnabled' internal/platform/moewiring/config.go
grep -q 'RegisterAll' internal/platform/moekratos/app.go

go test ./internal/platform/kratosprogress/... -count=1
go test ./api/internal/admingw/... -count=1
go test ./api/moekratospilot/... -count=1

go build -o /dev/null ./cmd/moe-kratos

echo "OK: PK-3 pilot domains on moekratospilot (RegisterAll)"
