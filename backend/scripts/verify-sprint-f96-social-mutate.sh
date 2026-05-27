#!/usr/bin/env bash
# F96：Post delete/update/report → biz + postgw
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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
