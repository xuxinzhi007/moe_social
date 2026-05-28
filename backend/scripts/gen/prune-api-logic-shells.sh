#!/usr/bin/env bash
# 删除 goctl api 生成的空壳 logic（兼容 macOS bash 3.2）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGIC_ROOT="$ROOT/api/internal/logic"
HANDLER_ROOT="$ROOT/api/internal/handler"
removed=0

prune_admin_insights_dupes() {
  local canonical="$LOGIC_ROOT/admin/admin_insights_logic.go"
  [[ -f "$canonical" ]] || return 0
  local f base t ct
  while IFS= read -r ct; do
    [[ -n "$ct" ]] || continue
    for f in "$LOGIC_ROOT"/admin/admin*.go; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f")"
      [[ "$base" == "admin_insights_logic.go" ]] && continue
      grep -q 'todo: add your logic' "$f" || continue
      t="$(grep -m1 -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//')"
      [[ "$t" == "$ct" ]] || continue
      echo "prune-api-logic-shells: remove $base (duplicate $t)"
      rm -f "$f"
      removed=$((removed + 1))
    done
  done < <(grep -E '^type [A-Za-z0-9_]+Logic struct' "$canonical" | sed 's/type //;s/ struct.*//')
}

prune_unreferenced_todo_shells() {
  local f logic_type ctor
  find "$LOGIC_ROOT" -name '*logic.go' -type f | while IFS= read -r f; do
    grep -q 'todo: add your logic' "$f" || continue
    logic_type="$(grep -m1 -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//')"
    [[ -n "$logic_type" ]] || continue
    ctor="New${logic_type}"
    if grep -rq "${ctor}(" "$HANDLER_ROOT/" 2>/dev/null; then
      continue
    fi
    echo "prune-api-logic-shells: remove $(basename "$f") (unreferenced $ctor)"
    rm -f "$f"
    removed=$((removed + 1))
  done
}

prune_manifest_stubs() {
  local manifest="$ROOT/scripts/goctl-orphan-stubs.txt"
  [[ -f "$manifest" ]] || return 0
  local rel path
  while IFS= read -r rel || [[ -n "${rel:-}" ]]; do
    rel="${rel%%#*}"
    rel="$(printf '%s' "$rel" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$rel" ]] && continue
    path="$ROOT/$rel"
    if [[ -f "$path" ]]; then
      echo "prune-api-logic-shells: remove manifest $rel"
      rm -f "$path"
      removed=$((removed + 1))
    fi
  done < "$manifest"
}

prune_admin_insights_dupes
prune_unreferenced_todo_shells
prune_manifest_stubs
echo "prune-api-logic-shells: removed $removed file(s)"
