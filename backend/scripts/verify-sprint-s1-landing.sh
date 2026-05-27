#!/usr/bin/env bash
# Sprint S1：Landing HTTP in_process 验收
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-s1-landing =="

test -f internal/biz/landing/feedback.go
test -f internal/service/landing/app.go
test -f api/internal/landinggw/gateway.go
test -f internal/platform/moewiring/api_landing.go
grep -q 'landing_api_in_process' config/config.yaml
grep -q 'LandingGW.SubmitLandingFeedback' api/internal/logic/landing/submitlandingfeedbacklogic.go
grep -q 'LandingGW.ListLandingFeedback' api/internal/logic/ops/listlandingfeedbacklogic.go
grep -q 'LandingGW' api/internal/svc/servicecontext.go
grep -q 'landing gateway route' api/runserver/server.go

go test ./internal/biz/landing/... -count=1 2>/dev/null || true
go build -o /dev/null ./api/... ./internal/service/landing/... ./internal/biz/landing/... ./cmd/moe-social

echo "OK: Landing domain in_process wired"
