#!/usr/bin/env bash
# PK-12：完整纯 Kratos 100%（传输 + 路由 + gRPC；生产 make moe-social）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-pure-100 =="

grep -q 'kratos_pure_enabled: true' config/config.yaml
grep -q 'runtime:' config/config.yaml
grep -q 'http_port: 8888' config/config.yaml
test -f cmd/moe-social/main.go
grep -q 'Unified config (SSOT)' cmd/moe-social/main.go
grep -q 'kratos_super_grpc_native: true' config/config.yaml
grep -q 'kratos_pk8_goctl_retired: true' config/config.yaml
grep -q 'unified_entry: moe-social' config/config.yaml
grep -q '8888' config/config.yaml

test -f internal/platform/moesocial/kratos_pure_http.go
test -f internal/platform/moesocial/run_kratos_grpc.go
test -f rpc/runserver/kratos.go
test -f api/moekratospilot/routes_native_gen.go
test -f api/moekratospilot/routes_bridge_gen.go

! grep -q '/api/posts' api/moekratospilot/routes_bridge_gen.go
bridge_n=$(grep -c 'wrapGoZeroHandler' api/moekratospilot/routes_bridge_gen.go || true)
if [ "$bridge_n" -gt 2 ]; then
  echo "expected bridge <= 2 (swagger), got wrapGoZeroHandler count=$bridge_n" >&2
  exit 1
fi

go test ./internal/platform/kratosprogress/... -count=1 -run 'TestCompletePureKratosAtLeast100|TestCompletePureBreakdown100WhenPure|TestRolloutPercentAtLeast100WhenPure'
go test ./api/moekratospilot/... -count=1
go build -o /dev/null ./cmd/moe-social-stack/...

echo "OK: complete pure Kratos 100% — run: make moe-social && curl -s :8888/migration"
