#!/usr/bin/env bash
set -euo pipefail
: # moe_backend_cd

echo "== gen-moe-proto =="
bash scripts/gen-moe-proto.sh

test -f api/moe/v1/moe.pb.go
test -f api/moe/v1/moe_grpc.pb.go
grep -q 'RegisterMoeAdminServer' api/moe/v1/moe_grpc.pb.go
grep -q 'func (s \*Server) ListRuntimes' internal/server/moegrpc/server.go
grep -q 'RegisterMoeGRPC' rpc/internal/bootstrap/moe_grpc_register.go

go build -o /dev/null ./api ./rpc ./cmd/moe-platform ./internal/server/moegrpc/...

echo "OK: Moe gRPC layer verification passed"
