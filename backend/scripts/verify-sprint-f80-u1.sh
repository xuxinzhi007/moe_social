#!/usr/bin/env bash
# Sprint F80 U1：User 通知 4 接口 → biz/notify + usergw
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f80-u1 =="

test -f internal/biz/notify/inbox.go
grep -q 'GetNotifications' internal/service/user/app.go
grep -q 'func (g \*Gateway) GetNotifications' api/internal/usergw/gateway.go
grep -q 'UserGW.GetNotifications' api/internal/logic/notification/getnotificationslogic.go
grep -q 'UserGW.GetUnreadCount' api/internal/logic/notification/getunreadcountlogic.go
grep -q 'notifybiz.ListInbox' rpc/internal/logic/getnotificationslogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/notify/... ./cmd/moe-social

echo "OK: User notification inbox in_process wired"
