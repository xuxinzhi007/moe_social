#!/usr/bin/env bash
# FS-9b phase 1: pb/moe 生成 + pb/super 垫片（proto package 仍为 super）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-sprint-fs9b (phase 1) =="

grep -q 'backend/rpc/pb/moe' rpc/defs/common.proto
grep -q 'backend/rpc/pb/moe' rpc/moe.proto

test -d rpc/pb/moe
test -f rpc/pb/moe/common.pb.go
test -f rpc/pb/super/shim_gen.go
grep -q 'package moe' rpc/pb/moe/common.pb.go
grep -q 'package super' rpc/pb/super/shim_gen.go
grep -q 'type RegisterReq = moe.RegisterReq' rpc/pb/super/shim_gen.go

go build -o /dev/null ./rpc/pb/moe/...
go build -o /dev/null ./rpc/pb/super/...
go build -o /dev/null ./rpc/superclient/...

echo "OK: FS-9b phase 1 (pb/moe + super shim)"
