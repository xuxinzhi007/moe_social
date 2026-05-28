#!/usr/bin/env bash
# F97：Admin 公告写路径 create/update/publish/delete → biz + admingw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f97-admin-announcements-write =="

test -f internal/biz/admin/announcements_write.go
grep -q 'CreateAnnouncement' internal/service/admin/app.go
grep -q 'AdminGW.AdminCreateAnnouncement' api/internal/logic/admin/admincreateannouncementlogic.go
grep -q 'AdminGW.AdminPublishAnnouncement' api/internal/logic/admin/adminpublishannouncementlogic.go
grep -q 'adminapp.New' rpc/internal/logic/admincreateannouncementlogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./internal/service/admin/... ./cmd/moe-social
echo "OK: admin announcement write in_process"
