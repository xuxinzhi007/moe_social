#!/usr/bin/env bash
# P4-H：goctl 重生 routes.go 后补 //go:build hybrid，使默认构建不拉入 handler 子包。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROUTES="$ROOT/api/internal/handler/routes.go"

if [[ ! -f "$ROUTES" ]]; then
  echo "tag-hybrid-routes: $ROUTES missing, skip"
  exit 0
fi

if head -n 1 "$ROUTES" | grep -q '^//go:build hybrid'; then
  echo "tag-hybrid-routes: already tagged"
  exit 0
fi

tmp="$(mktemp)"
{
  echo '//go:build hybrid'
  echo ''
  cat "$ROUTES"
} >"$tmp"
mv "$tmp" "$ROUTES"
echo "tag-hybrid-routes: added //go:build hybrid to routes.go"
