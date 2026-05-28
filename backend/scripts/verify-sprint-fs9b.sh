#!/usr/bin/env bash
# FS-9b phase 1: pb/moe 生成 + pb/super 垫片（proto package 仍为 super）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-sprint-fs9b =="

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

# phase 2: 业务代码直引 pb/moe（垫片 scripts/、shim 目录除外）
super_imports=$(grep -r --include='*.go' -l '"backend/rpc/pb/super"' . 2>/dev/null \
  | grep -v 'rpc/pb/super/' \
  | grep -v '/scripts/' || true)
if [ -n "$super_imports" ]; then
  echo "FS-9b phase2: unexpected pb/super imports:" >&2
  echo "$super_imports" >&2
  exit 1
fi

go build -o /dev/null ./rpc/... ./api/... ./internal/...

echo "OK: FS-9b (pb/moe + shim; internal imports migrated)"
