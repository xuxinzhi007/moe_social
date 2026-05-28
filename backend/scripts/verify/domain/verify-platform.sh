#!/usr/bin/env bash
# 平台基建 FS-1 验收（单二进制可构建）
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"
cd "$ROOT"

echo "== verify-platform =="

make build-moe-social
test -f bin/moe-social

echo "OK: platform build-moe-social"
