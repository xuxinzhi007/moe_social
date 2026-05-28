#!/usr/bin/env bash
# F101：Admin 用户/成就/菜单/话题 bootstrap → biz/admin + admingw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f101-admin =="

test -f internal/biz/admin/users.go
test -f internal/biz/admin/achievements.go
test -f internal/biz/admin/menus.go
grep -q 'func (s \*AppService) ListUsers' internal/service/admin/app.go
grep -q 'AdminListUsers' api/internal/admingw/gateway.go
grep -q 'AdminGW.AdminListUsers' api/internal/logic/admin/adminlistuserslogic.go
grep -q 'AdminGW.AdminListAchievements' api/internal/logic/admin/adminlistachievementslogic.go
grep -q 'AdminGW.AdminListMenus' api/internal/logic/admin/adminlistmenuslogic.go
grep -q 'AdminGW.AdminBootstrapTopicTags' api/internal/logic/admin/adminbootstraptopictagslogic.go
grep -q 'adminapp.New(l.svcCtx.DB).ListUsers' rpc/internal/logic/adminlistuserslogic.go
grep -q 'adminbiz.ListUsers' internal/biz/admin/users.go

go test ./internal/biz/admin/... -count=1
go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./internal/service/admin/...
echo "OK: admin users/achievements/menus/topic-bootstrap in_process (F101)"
