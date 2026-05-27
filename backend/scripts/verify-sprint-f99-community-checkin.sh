#!/usr/bin/env bash
# F99：checkin + achievement HTTP → biz + gw
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f99-community-checkin =="

test -f internal/biz/checkin/checkin.go
test -f internal/biz/achievement/query.go
test -f api/internal/checkinwg/gateway.go
test -f api/internal/achievementgw/gateway.go
grep -q 'CheckInGW.GetCheckInStatus' api/internal/logic/checkin/getcheckinstatuslogic.go
grep -q 'AchievementGW.GetUserAchievements' api/internal/logic/achievement/getuserachievementslogic.go
grep -q 'checkinapp.New' rpc/internal/logic/checkinlogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/checkin/... ./internal/biz/achievement/... ./cmd/moe-social
echo "OK: checkin + achievement in_process"
