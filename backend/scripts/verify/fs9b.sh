#!/usr/bin/env bash
# FS-9b phase2: 业务 import pb/moe（垫片目录除外）。
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify/fs9b =="

test -f rpc/pb/moe/doc.go
test -f rpc/pb/super/shim_gen.go

super_imports=$(grep -r --include='*.go' -l '"backend/rpc/pb/super"' . 2>/dev/null \
  | grep -v 'rpc/pb/super/' \
  | grep -v '/scripts/' || true)
if [ -n "$super_imports" ]; then
  echo "FS-9b phase2: unexpected pb/super imports:" >&2
  echo "$super_imports" >&2
  exit 1
fi

go build -o /dev/null ./rpc/pb/moe/...

echo "OK: FS-9b pb/moe + shim"
