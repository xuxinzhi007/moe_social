#!/usr/bin/env bash
# F80-A1：Admin 公告 list/get → biz/admin
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f80-a1 =="

test -f internal/biz/admin/announcements.go
grep -q 'ListAnnouncements' internal/service/admin/app.go
grep -q 'AdminListAnnouncements' api/internal/admingw/gateway.go
grep -q 'AdminGW.AdminListAnnouncements' api/internal/logic/admin/adminlistannouncementslogic.go
grep -q 'adminbiz.ListAnnouncements' rpc/internal/logic/adminlistannouncementslogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./cmd/moe-social
echo "OK: Admin announcements in_process"
