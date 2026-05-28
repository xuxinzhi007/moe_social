#!/usr/bin/env bash
# Sprint F90：comment list + admin audit
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f90 =="

test -f internal/biz/comment/list.go
test -f api/internal/commentgw/gateway.go
grep -q 'CommentGW.GetPostComments' api/internal/logic/post/getpostcommentslogic.go
grep -q 'AdminGW.AdminListAuditLogs' api/internal/logic/admin/adminlistauditlogslogic.go
grep -q 'adminbiz.ListAuditLogs' rpc/internal/logic/adminlistauditlogslogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/comment/... ./cmd/moe-social
echo "OK: Sprint F90 partial verified"
