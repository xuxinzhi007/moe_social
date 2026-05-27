#!/usr/bin/env bash
# FS-3：User 域核心 Hybrid 验收
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-domain-user =="

test -f internal/biz/user/auth.go
test -f internal/biz/user/follow.go
test -f internal/service/user/app.go
test -f api/internal/usergw/gateway.go
grep -q 'user_api_in_process' config/config.yaml
grep -q 'userbiz.Follow' rpc/internal/logic/followuserlogic.go
grep -q 'UserGW.FollowUser' api/internal/logic/user/followuserlogic.go

go test ./internal/biz/user/... -count=1
go build -o /dev/null ./api/... ./internal/biz/user/... ./internal/service/user/... ./cmd/moe-social

echo "OK: User domain core (auth/profile/vip status) compile"
