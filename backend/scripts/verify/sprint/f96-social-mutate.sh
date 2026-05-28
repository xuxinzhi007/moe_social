#!/usr/bin/env bash
# F96：Post delete/update/report → biz + postgw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f96-social-mutate =="

test -f internal/biz/post/delete.go
test -f internal/biz/post/update.go
test -f internal/biz/post/report.go
grep -q 'DeletePost' internal/service/post/app.go
grep -q 'PostGW.DeletePost' api/internal/logic/post/deletepostlogic.go
grep -q 'PostGW.UpdatePost' api/internal/logic/post/updatepostlogic.go
grep -q 'PostGW.ReportPost' api/internal/logic/post/reportpostlogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/post/... ./cmd/moe-social
echo "OK: social mutate (delete/update/report) in_process"
