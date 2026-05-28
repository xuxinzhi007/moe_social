#!/usr/bin/env bash
# FS-10: RPC internal/logic 不得直写 GORM（查询在 biz/service；合并文件与 map/helper 除外）。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bad=0

allow=(
  admin_helpers.go
  admin_insights_logic.go
  moe_admin_logic.go
  adminbiz_map.go
  rpc_apps.go
  ai_rpc_helper.go
  ai_user_config_logic.go
  vipplan_helper.go
  vipplan_biz.go
  posthelpers.go
  user_behavior_helpers.go
  friendrelationlogic.go
  recordadminauditloglogic.go
)

is_allowed() {
  local base="$1"
  local f
  for f in "${allow[@]}"; do
    [[ "$base" == "$f" ]] && return 0
  done
  return 1
}

while IFS= read -r f; do
  base="$(basename "$f")"
  is_allowed "$base" && continue
  if grep -qE '\.(Model|Where|First|Find|Create|Save|Updates|Delete)\(' "$f"; then
    echo "FS-10: fat RPC logic: ${f#"$root"/}"
    bad=1
  fi
done < <(find rpc/internal/logic -name '*.go' -type f)

if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "OK: RPC logic thin (no direct GORM outside allowlist)"
