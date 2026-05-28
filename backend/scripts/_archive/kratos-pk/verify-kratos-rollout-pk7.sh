#!/usr/bin/env bash
# PK-7: zrpc 由 kratos.App 管理（transport/grpc 适配）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-rollout-pk7 =="

test -f internal/platform/moesocial/kratos_grpc.go
grep -q 'wrapZRPC' internal/platform/moesocial/run.go
grep -q 'KratosGRPCManaged' internal/platform/moewiring/config.go
grep -q 'kratos_grpc_managed' config/config.yaml
grep -q 'kratos_grpc_managed' internal/conf/moe/v1/pilot.proto

go build -o /dev/null ./cmd/moe-social-stack

echo "OK: PK-7 Kratos-managed zrpc (enable with moe.kratos_grpc_managed=true)"
