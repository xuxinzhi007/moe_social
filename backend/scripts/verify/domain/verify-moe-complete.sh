#!/usr/bin/env bash
set -euo pipefail
: # moe_backend_cd

bash "$(dirname "$0")/verify-moe-migration.sh
bash "$(dirname "$0")/verify-moe-grpc.sh
bash "$(dirname "$0")/verify-moe-gateway.sh

echo "== moe-social single process build =="
go build -o /dev/null ./cmd/moe-social
test -f cmd/moe-social/main.go
test -f internal/platform/moesocial/run.go
grep -q 'moe-social' internal/platform/moesocial/run.go

echo "OK: Moe complete migration verification passed (100%)"
