#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== moeadmingw gateway =="
test -f api/internal/moeadmingw/gateway.go
grep -q 'func (g \*Gateway) ListRuntimes' api/internal/moeadmingw/gateway.go
grep -q 'MoeGW' api/internal/svc/servicecontext.go
grep -q 'use_moe_grpc' config/config.yaml

echo "== kratos in go.mod =="
grep -q 'go-kratos/kratos' go.mod

go build -o /dev/null ./api ./rpc ./cmd/moe-platform ./api/internal/moeadmingw/...

echo "OK: Moe admin gateway verification passed (~80%)"
