#!/usr/bin/env bash
# FS-3：User 域核心 Hybrid 验收
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-domain-user =="

test -f internal/biz/user/auth.go
test -f internal/biz/user/follow.go
test -f internal/biz/user/friend.go
test -f internal/service/user/app.go
test -f api/internal/usergw/gateway.go
grep -q 'user_api_in_process' config/config.yaml
grep -q 'userbiz.Follow' rpc/internal/logic/followuserlogic.go
grep -q 'UserGW.FollowUser' api/internal/logic/user/followuserlogic.go
grep -q 'func SendFriendRequest' internal/biz/user/friend.go
grep -q 'UserGW.SendFriendRequest' api/internal/logic/user/friendlogic.go

go test ./internal/biz/user/... -count=1
go build -o /dev/null ./api/... ./internal/biz/user/... ./internal/service/user/... ./cmd/moe-social

echo "OK: User domain (auth/follow/friend) compile"
