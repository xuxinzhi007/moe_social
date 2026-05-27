#!/usr/bin/env bash
# Sprint S5：Admin 通知 broadcast/send → biz/notify
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-s5-notify =="

test -f internal/biz/notify/admin.go
test -f internal/biz/notify/content.go
grep -q 'BroadcastNotification' internal/service/admin/app.go
grep -q 'AdminBroadcastNotification' api/internal/admingw/gateway.go
grep -q 'AdminGW.AdminBroadcastNotification' api/internal/logic/admin/adminbroadcastnotificationlogic.go
grep -q 'AdminGW.AdminSendNotification' api/internal/logic/admin/adminsendnotificationlogic.go
grep -q 'notifybiz.Broadcast' rpc/internal/logic/adminbroadcastnotificationlogic.go
grep -q 'notifybiz.SendToUser' rpc/internal/logic/adminsendnotificationlogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/notify/... ./cmd/moe-social

echo "OK: Admin notify in_process wired"
