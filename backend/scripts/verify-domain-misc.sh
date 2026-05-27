#!/usr/bin/env bash
# FS-3c：小域快迁（landing / behavior / appcfg）验收
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-domain-misc =="

test -f internal/biz/landing/feedback.go
test -f internal/biz/behavior/track.go
test -f internal/biz/appcfg/public.go

grep -q 'landingbiz.Submit' rpc/internal/logic/submitlandingfeedbacklogic.go
grep -q 'landingbiz.List' rpc/internal/logic/listlandingfeedbacklogic.go
grep -q 'behaviorbiz.TrackEvents' rpc/internal/logic/trackuserbehavioreventslogic.go
grep -q 'appcfgbiz.NormalizePublicAPIBaseURL' api/internal/logic/appcfg/publicclientconfiglogic.go

go build -o /dev/null ./internal/biz/landing/... ./internal/biz/behavior/... ./internal/biz/appcfg/...
go build -o /dev/null ./cmd/moe-social

echo "OK: misc domains (landing, behavior, appcfg) compile"
