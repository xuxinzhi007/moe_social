#!/usr/bin/env bash
# F92：社交写路径 Post/Comment create → biz + gw
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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
