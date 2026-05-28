#!/usr/bin/env bash
# FS-10a: Admin RPC logic 不得直写 DB（查询须在 biz/service）。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bad=0

allow=(
  admin_helpers.go
  admin_insights_logic.go
  moe_admin_logic.go
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
  if grep -qE '\.Model\(|\.Where\(|\.First\(|\.Find\(|\.Create\(|\.Save\(' "$f"; then
    echo "FS-10: fat RPC logic: ${f#"$root"/}"
    bad=1
  fi
done < <(find rpc/internal/logic -name 'admin*.go' -type f)

if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "OK: admin RPC logic thin (no direct GORM in handler files)"
