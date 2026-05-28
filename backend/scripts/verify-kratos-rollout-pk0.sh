#!/usr/bin/env bash
# PK-0: 纯 Kratos 落地基线（试点存在 + Hybrid 契约 + 关键文档）。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-kratos-rollout-pk0 =="

test -f cmd/moe-kratos/main.go
test -f internal/platform/moekratos/run.go
test -f internal/platform/moekratos/wire_gen.go
test -f api/moe/v1/moe.proto
test -f ../docs/dev/kratos-pure-rollout.md

test -f api/moe.api
test -f rpc/moe.proto
test -f api/etc/moe.yaml
test -f rpc/etc/moe.yaml

if [ -f api/super.api ] || [ -f rpc/super.proto ]; then
  echo "PK-0: legacy super.api / super.proto must be absent (FS-9)"
  exit 1
fi
if [ -f api/etc/super.yaml ] || [ -f rpc/etc/super.yaml ]; then
  echo "PK-0: legacy super.yaml must be absent (FS-9)"
  exit 1
fi

bash scripts/verify-kratos-pilot.sh

echo "OK: PK-0 pure Kratos rollout baseline"
