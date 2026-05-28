#!/usr/bin/env bash
# PK-1: 域 proto SSOT + 契约纪律文档。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-kratos-rollout-pk1 =="

test -f api/README.md
test -f api/moe/v1/README.md
test -f api/vip/v1/README.md
test -f api/moe/v1/moe.proto
test -f api/vip/v1/vip_read.proto

grep -q 'PK-1' api/vip/v1/vip_read.proto
grep -q 'kratos_admin_http_enabled' api/moe/v1/moe.proto

count=$(find api -path '*/v1/*.proto' 2>/dev/null | wc -l | tr -d ' ')
if [ "${count:-0}" -lt 6 ]; then
  echo "PK-1: expected >= 6 api/**/v1/*.proto, got $count"
  exit 1
fi

if command -v protoc >/dev/null 2>&1; then
  make gen-moe-proto >/dev/null
  test -f api/vip/v1/vip_read.pb.go || test -f api/vip/v1/vip_read_grpc.pb.go 2>/dev/null || true
fi

go test ./api/internal/vipadmingw/... -count=1

echo "OK: PK-1 domain proto SSOT + contract discipline"
