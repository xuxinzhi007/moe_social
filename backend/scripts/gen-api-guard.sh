#!/usr/bin/env bash
# PK-8: 默认禁止 goctl api 覆盖 handler/routes（除非显式允许）。
set -euo pipefail
if [ "${MOE_ALLOW_GOCTL_API:-}" = "1" ]; then
  echo "gen-api: MOE_ALLOW_GOCTL_API=1 — running goctl api"
  exit 0
fi
echo "PK-8: gen-api blocked (set MOE_ALLOW_GOCTL_API=1 to override)" >&2
echo "  · HTTP routes: make gen-moekratospilot-get" >&2
echo "  · API defs SSOT: api/defs/*.api" >&2
exit 1
