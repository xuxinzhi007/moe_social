#!/usr/bin/env bash
# Sprint F90：comment list + admin audit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f90 =="

test -f internal/biz/comment/list.go
test -f api/internal/commentgw/gateway.go
grep -q 'CommentGW.GetPostComments' api/internal/logic/post/getpostcommentslogic.go
grep -q 'AdminGW.AdminListAuditLogs' api/internal/logic/admin/adminlistauditlogslogic.go
grep -q 'adminbiz.ListAuditLogs' rpc/internal/logic/adminlistauditlogslogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/comment/... ./cmd/moe-social
echo "OK: Sprint F90 partial verified"
