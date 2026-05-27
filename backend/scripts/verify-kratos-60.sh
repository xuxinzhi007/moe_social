#!/usr/bin/env bash
# 纯 Kratos 进度 60% 验收（Phase 0～3）
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-50.sh

echo "== Phase 3: gateway gray release =="
grep -q 'kratos_admin_http_enabled' config/config.yaml
grep -q 'KratosAdminHTTPEnabled' internal/platform/moewiring/config.go
grep -q 'NewConfigured' api/internal/moeadmingw/gateway_factory.go
grep -q 'kratosHTTPReady' api/internal/moeadmingw/gateway.go
go test ./api/internal/moeadmingw/... -count=1 -run 'Kratos|GatewayRoute'

echo ""
echo "OK: pure kratos migration at 60% (phase 0-3)"
