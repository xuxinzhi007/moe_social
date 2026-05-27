#!/usr/bin/env bash
# Sprint S4：appcfg/doc 已 in_process + behavior HTTP 网关
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-s4-misc =="

test -f internal/biz/appcfg/public.go
test -f internal/biz/behavior/track.go
test -f internal/service/behavior/app.go
test -f api/internal/behaviorgw/gateway.go
test -f api/internal/logic/doc/swaggerdoclogic.go
grep -q 'appcfgbiz.NormalizePublicAPIBaseURL' api/internal/logic/appcfg/publicclientconfiglogic.go
grep -q 'BehaviorGW.TrackUserBehaviorEvents' api/internal/logic/behavior/trackuserbehavioreventslogic.go
grep -q 'behavior_api_in_process' config/config.yaml
grep -q 'BehaviorGW' api/internal/svc/servicecontext.go

go build -o /dev/null ./api/... ./internal/biz/behavior/... ./internal/service/behavior/... ./cmd/moe-social

echo "OK: misc (appcfg/doc/behavior) in_process wired"
