#!/usr/bin/env bash
# F100d：Community 群组全路径 → biz/community + communitygw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f100d-community =="

test -f internal/biz/community/query.go
test -f internal/biz/community/mutate.go
test -f api/internal/communitygw/gateway.go
grep -q 'CommunityGW.GetGroups' api/internal/logic/community/getgroupslogic.go
grep -q 'CommunityGW.CreateGroup' api/internal/logic/community/creategrouplogic.go
grep -q 'CommunityGW.CreateGroupPost' api/internal/logic/community/creategrouppostlogic.go
grep -q 'communityapp.New' rpc/internal/logic/getgroupslogic.go
grep -q 'community_api_in_process' config/config.yaml

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/community/... ./cmd/moe-social
echo "OK: community domain in_process (F100d)"
