#!/usr/bin/env bash
# Sprint S3：Admin 只读 3 接口 → biz/admin 验收
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-s3-admin-ro =="

test -f internal/biz/admin/insights.go
test -f internal/service/admin/app.go
test -f api/internal/admingw/gateway.go
test -f internal/platform/moewiring/api_admin_readonly.go
grep -q 'admin_readonly_api_in_process' config/config.yaml
grep -q 'AdminGW.AdminGetGrowthStats' api/internal/logic/admin/admingetgrowthstatslogic.go
grep -q 'AdminGW.AdminGetSchemaCatalog' api/internal/logic/admin/admingetschemacataloglogic.go
grep -q 'AdminGW.ReadRuntimeConfig' api/internal/logic/admin/admingetruntimeconfiglogic.go
grep -q 'adminbiz.GrowthStats' rpc/internal/logic/admingetgrowthstatslogic.go
grep -q 'adminbiz.SchemaCatalog' rpc/internal/logic/admingetschemacataloglogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./internal/service/admin/... ./cmd/moe-social

echo "OK: Admin readonly in_process wired"
