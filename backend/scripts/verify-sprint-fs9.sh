#!/usr/bin/env bash
# FS-9: 退役 legacy super.api/super.proto 文件名；契约 SSOT 在 defs/；单进程回归。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-sprint-fs9 =="

test -f api/moe.api
test -f rpc/moe.proto
test -f api/etc/moe.yaml
test -f rpc/etc/moe.yaml

if [ -f api/super.api ] || [ -f rpc/super.proto ]; then
  echo "FS-9: legacy super.api / super.proto must be removed (use moe.api / moe.proto)"
  exit 1
fi

if [ -f api/etc/super.yaml ] || [ -f rpc/etc/super.yaml ]; then
  echo "FS-9: legacy super.yaml must be removed (use moe.yaml)"
  exit 1
fi

grep -q 'api/etc/moe.yaml' cmd/moe-social-stack/main.go
grep -q 'rpc/etc/moe.yaml' cmd/moe-social-stack/main.go

bash scripts/verify-sprint-fs8b.sh

echo "OK: FS-9 legacy contract filenames retired; moe-social monolith regression passed"
