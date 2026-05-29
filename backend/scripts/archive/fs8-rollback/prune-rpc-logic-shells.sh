#!/usr/bin/env bash
# 删除 goctl rpc 与合并 logic 冲突的空壳（兼容 macOS bash 3.2）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOGIC_DIR="$ROOT/rpc/internal/logic"
removed=0

if [[ -d "$LOGIC_DIR" ]]; then
  canonical_types() {
    local f
    for f in \
      "$LOGIC_DIR/moe_admin_logic.go" \
      "$LOGIC_DIR/admin_insights_logic.go"; do
      [[ -f "$f" ]] || continue
      grep -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//'
    done | sort -u
  }

  f="" base="" t="" ct=""
  while IFS= read -r ct; do
    [[ -n "$ct" ]] || continue
    for f in "$LOGIC_DIR"/admin*.go "$LOGIC_DIR"/moe*.go; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f")"
      case "$base" in
        moe_admin_logic.go|admin_insights_logic.go|moe_proto_convert.go) continue ;;
      esac
      grep -q 'todo: add your logic' "$f" || continue
      t="$(grep -m1 -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//')"
      [[ "$t" == "$ct" ]] || continue
      echo "prune-rpc-logic-shells: remove $base (duplicate $t)"
      rm -f "$f"
      removed=$((removed + 1))
    done
  done < <(canonical_types)
fi

manifest="$ROOT/scripts/goctl-rpc-orphan-stubs.txt"
if [[ -f "$manifest" ]]; then
  rel="" path=""
  while IFS= read -r rel || [[ -n "${rel:-}" ]]; do
    rel="${rel%%#*}"
    rel="$(printf '%s' "$rel" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$rel" ]] && continue
    path="$ROOT/$rel"
    if [[ -f "$path" ]]; then
      echo "prune-rpc-logic-shells: remove manifest $rel"
      rm -f "$path"
      removed=$((removed + 1))
    fi
  done < "$manifest"
fi

echo "prune-rpc-logic-shells: removed $removed file(s)"
