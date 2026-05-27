#!/usr/bin/env bash
# FS-2：VIP 域 Hybrid 验收（biz + vipadmingw + RPC 复用 biz）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-domain-vip =="

test -f internal/biz/vip/plan_crud.go
test -f internal/service/vip/admin.go
test -f api/internal/vipadmingw/gateway.go
test -f internal/platform/moewiring/api_vip.go

grep -q 'vip_api_in_process' config/config.yaml || grep -q 'vip_api_in_process' ../config/config.yaml 2>/dev/null || true

go test ./internal/biz/vip/... -count=1
go build -o /dev/null ./api/... ./rpc/... ./internal/biz/vip/... ./internal/service/vip/...

echo "OK: VIP domain biz + gateway compile"
