#!/usr/bin/env bash
# 纯 Kratos 进度 50% 验收（Phase 0+1+2 静态 + 可选 live）
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Phase 0: build moe-kratos =="
go build -o /dev/null ./cmd/moe-kratos

echo "== Phase 1+2: sources =="
test -f api/moekratospilot/admin_compat.go
test -f scripts/grpcurl-moe-kratos.sh
grep -qE 'Register(AdminCompat|All)' internal/platform/moekratos/app.go
grep -q '/api/admin/moe/runtimes' api/moekratospilot/admin_compat.go
grep -q 'moe-kratos-pilot' internal/server/moekratoshttp/register.go

echo "== unit: admin compat JSON shape =="
go test ./api/moekratospilot/... -count=1

if [ "${MOE_KRATOS_LIVE:-}" = "1" ]; then
  echo "== live HTTP (MOE_KRATOS_LIVE=1) =="
  curl -sf "http://127.0.0.1:19032/health" >/dev/null
  curl -sf "http://127.0.0.1:8888/migration" | grep -qE '"percent":[1-9][0-9]'
  curl -sf "http://127.0.0.1:19032/api/admin/moe/runtimes" | grep -q '"code":'
  bash scripts/grpcurl-moe-kratos.sh
fi

echo ""
echo "OK: pure kratos migration at 50% (phase 0+1+2)"
