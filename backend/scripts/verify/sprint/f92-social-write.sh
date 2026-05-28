#!/usr/bin/env bash
# F92：社交写路径 Post/Comment create → biz + gw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f92-social-write =="

test -f internal/biz/post/create.go
test -f internal/biz/comment/create.go
grep -q 'CreatePost' internal/service/post/app.go
grep -q 'CreateComment' internal/service/comment/app.go
grep -q 'PostGW.CreatePost' api/internal/logic/post/createpostlogic.go
grep -q 'CommentGW.CreateComment' api/internal/logic/comment/createcommentlogic.go
grep -q 'postapp.New' rpc/internal/logic/createpostlogic.go
grep -q 'commentapp.New' rpc/internal/logic/createcommentlogic.go
grep -q 'socialhook.ApplyPostCreatedAchievements' internal/service/post/app.go
grep -q 'RegisterSocialAchievementHooks' rpc/runserver/server.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/post/... ./internal/biz/comment/... ./cmd/moe-social
echo "OK: social write (create post/comment) in_process"
