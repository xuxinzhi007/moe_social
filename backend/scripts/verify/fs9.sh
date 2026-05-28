#!/usr/bin/env bash
# FS-9: moe.api / moe.proto 契约文件名；无 legacy super.*。
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify/fs9 =="

test -f api/moe.api
test -f rpc/moe.proto
test -f api/etc/moe.yaml
test -f rpc/etc/moe.yaml

if [ -f api/super.api ] || [ -f rpc/super.proto ]; then
  echo "FS-9: legacy super.api / super.proto must be removed"
  exit 1
fi
if [ -f api/etc/super.yaml ] || [ -f rpc/etc/super.yaml ]; then
  echo "FS-9: legacy super.yaml must be removed"
  exit 1
fi

grep -q 'config/config.yaml' cmd/moe-social/main.go
grep -q 'Unified config' cmd/moe-social/main.go

bash "$(dirname "$0")/sprint/fs8b.sh"

echo "OK: FS-9 contract filenames"
