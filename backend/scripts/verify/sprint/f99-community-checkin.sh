#!/usr/bin/env bash
# F99：checkin + achievement HTTP → biz + gw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

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
