#!/usr/bin/env bash
# PK-11: Super gRPC 使用 kratos/transport/grpc（非 zrpc）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-rollout-pk11 =="

test -f rpc/runserver/kratos.go
grep -q 'KratosSuperGRPCNative' internal/platform/moewiring/config.go
grep -q 'runWithKratosGRPC' internal/platform/moesocial/run.go
grep -q 'StartKratos' rpc/runserver/kratos.go
grep -q 'registerKratosGRPCServices' rpc/runserver/kratos.go
grep -q 'moerpc.RegisterSuperServer' rpc/runserver/kratos.go

go build -o /dev/null ./cmd/moe-social-stack/...

echo "OK: PK-11 kratos grpc for Super"
