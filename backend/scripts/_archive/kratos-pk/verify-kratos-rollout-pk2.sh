#!/usr/bin/env bash
# PK-2: Moe + VIP 生产灰度开关与 kratos_http 网关。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-kratos-rollout-pk2 =="

grep -q 'kratos_admin_http_enabled' config/config.yaml
grep -q 'kratos_vip_http_enabled' config/config.yaml
grep -q 'kratos_vip_http_enabled' internal/conf/moe/v1/pilot.proto

grep -q 'KratosVipHTTPEnabled' internal/platform/moewiring/config.go
grep -q 'NewConfigured' api/internal/vipadmingw/gateway_factory.go
grep -q 'kratos_http' api/internal/vipadmingw/gateway.go
grep -q 'ListRuntimes' api/internal/moeadmingw/gateway.go
grep -q 'kratosHTTPReady' api/internal/moeadmingw/gateway.go

go test ./api/internal/moeadmingw/... -count=1
go test ./api/internal/vipadmingw/... -count=1

bash scripts/verify-kratos-60.sh

echo "OK: PK-2 Moe/VIP kratos_http gray routing wired"
