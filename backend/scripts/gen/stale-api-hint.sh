#!/usr/bin/env bash
# 若 defs 比 routes.go 新，提示需要 gen-api（MOE_STRICT_GEN=1 时阻断 make gen）。
set -euo pipefail
cd "$(dirname "$0")/../.."
routes="api/internal/handler/routes.go"
[[ -f "$routes" ]] || exit 0
stale=0
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  if [[ "$f" -nt "$routes" ]]; then
    echo "stale-api-hint: $f 新于 routes.go — 请执行: make gen-api" >&2
    stale=1
  fi
done < <(find api/defs -name '*.api' 2>/dev/null; printf '%s\n' api/moe.api)
if [ "$stale" -ne 0 ] && [ "${MOE_STRICT_GEN:-}" = "1" ]; then
  exit 1
fi
exit 0
