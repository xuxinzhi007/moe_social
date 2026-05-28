#!/usr/bin/env bash
# F94：社交写路径 Post/Comment like → biz + gw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f94-social-like =="

test -f internal/biz/post/like.go
test -f internal/biz/comment/like.go
grep -q 'LikePost' internal/service/post/app.go
grep -q 'LikeComment' internal/service/comment/app.go
grep -q 'PostGW.LikePost' api/internal/logic/post/likepostlogic.go
grep -q 'CommentGW.LikeComment' api/internal/logic/comment/likecommentlogic.go
grep -q 'postapp.New' rpc/internal/logic/likepostlogic.go
grep -q 'commentapp.New' rpc/internal/logic/likecommentlogic.go
grep -q 'RegisterPostLikedAchievementHook' rpc/internal/bootstrap/social_hooks.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/post/... ./internal/biz/comment/... ./cmd/moe-social
echo "OK: social like (post/comment) in_process"
