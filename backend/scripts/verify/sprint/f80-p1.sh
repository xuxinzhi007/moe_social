#!/usr/bin/env bash
# F80-P1：Post search/get/list → biz/post + postgw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f80-p1 =="

test -f internal/biz/post/query.go
test -f api/internal/postgw/gateway.go
grep -q 'PostGW.MoeSearchPosts' api/internal/logic/post/searchpostslogic.go
grep -q 'PostGW.GetPosts' api/internal/logic/post/getpostslogic.go
grep -q 'postbiz.List' rpc/internal/logic/getpostslogic.go
grep -q 'post_api_in_process' config/config.yaml

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/post/... ./cmd/moe-social
echo "OK: Post domain in_process"
