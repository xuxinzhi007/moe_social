#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-moe-migration.sh
bash scripts/verify-moe-grpc.sh
bash scripts/verify-moe-gateway.sh

echo "== moe-social single process build =="
go build -o /dev/null ./cmd/moe-social
test -f cmd/moe-social/main.go
test -f internal/platform/moesocial/run.go
grep -q 'moe-social' internal/platform/moesocial/run.go

echo "OK: Moe complete migration verification passed (100%)"
