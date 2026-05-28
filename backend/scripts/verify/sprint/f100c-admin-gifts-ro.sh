#!/usr/bin/env bash
# F100c-a：Admin 礼物 list/get → biz/admin + admingw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f100c-admin-gifts-ro =="

test -f internal/biz/admin/gifts.go
grep -q 'AdminGW.AdminListGifts' api/internal/logic/admin/adminlistgiftslogic.go
grep -q 'AdminGW.AdminGetGift' api/internal/logic/admin/admingetgiftlogic.go
grep -q 'adminbiz.ListGifts' internal/service/admin/app.go
grep -q 'adminapp.New' rpc/internal/logic/adminlistgiftslogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./cmd/moe-social
echo "OK: admin gift read-only in_process (F100c-a)"
