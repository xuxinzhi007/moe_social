#!/usr/bin/env bash
# F98：achievement + level 抽包到 pkg/
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f98-achievement-pkg =="

test -f pkg/achievement/engine.go
test -f pkg/level/exp.go
! grep -rq 'rpc/internal/achievement' . --include='*.go' || (echo "still imports rpc/internal/achievement" && exit 1)
! grep -rq 'rpc/internal/level' . --include='*.go' || (echo "still imports rpc/internal/level" && exit 1)
grep -q 'backend/pkg/achievement' rpc/internal/bootstrap/social_hooks.go

go test ./pkg/achievement/... ./pkg/level/... -count=1
go build -o /dev/null ./api/... ./rpc/... ./pkg/achievement/... ./cmd/moe-social
echo "OK: achievement pkg extracted"
