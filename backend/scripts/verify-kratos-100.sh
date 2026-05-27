#!/usr/bin/env bash
# 纯 Kratos 迁移 100% 验收（Phase 0～6 + 生产单二进制）
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-80.sh

echo "== Phase 5: VIP read biz + pilot HTTP =="
test -f internal/biz/vip/plans.go
test -f api/moekratospilot/vip_compat.go
test -f api/vip/v1/vip_read.proto
go test ./internal/biz/vip/... -count=1

echo "== Phase 6: production unified binary =="
grep -q 'external_http_port' config/config.yaml
grep -q 'unified_entry: moe-social' config/config.yaml
grep -q 'production:' config/config.yaml
make build-moe-social
test -f bin/moe-social

echo "== Hybrid Moe 100% regression =="
bash scripts/verify-moe-complete.sh

echo ""
echo "OK: pure kratos migration at 100%; production HTTP remains :8888 (moe-social)"
