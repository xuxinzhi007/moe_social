#!/usr/bin/env bash
# F97：Admin 公告写路径 create/update/publish/delete → biz + admingw
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f97-admin-announcements-write =="

test -f internal/biz/admin/announcements_write.go
grep -q 'CreateAnnouncement' internal/service/admin/app.go
grep -q 'AdminGW.AdminCreateAnnouncement' api/internal/logic/admin/admincreateannouncementlogic.go
grep -q 'AdminGW.AdminPublishAnnouncement' api/internal/logic/admin/adminpublishannouncementlogic.go
grep -q 'adminapp.New' rpc/internal/logic/admincreateannouncementlogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./internal/service/admin/... ./cmd/moe-social
echo "OK: admin announcement write in_process"
