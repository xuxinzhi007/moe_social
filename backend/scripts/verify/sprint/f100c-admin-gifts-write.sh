#!/usr/bin/env bash
# F100c-b：Admin 礼物写 CRUD → biz/admin + admingw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f100c-admin-gifts-write =="

test -f internal/biz/admin/gifts_write.go
grep -q 'AdminGW.AdminCreateGift' api/internal/logic/admin/admincreategiftlogic.go
grep -q 'AdminGW.AdminUpdateGift' api/internal/logic/admin/adminupdategiftlogic.go
grep -q 'AdminGW.AdminDeleteGift' api/internal/logic/admin/admindeletegiftlogic.go
grep -q 'AdminGW.AdminBootstrapGifts' api/internal/logic/admin/adminbootstrapgiftslogic.go
grep -q 'adminbiz.CreateGift' internal/service/admin/app.go
grep -q 'adminapp.New' rpc/internal/logic/admincreategiftlogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./cmd/moe-social
echo "OK: admin gift write CRUD in_process (F100c-b)"
