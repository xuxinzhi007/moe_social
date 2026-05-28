#!/usr/bin/env bash
# 删除 goctl api 生成的空壳 logic（合并实现留在 *_logic.go / friendlogic.go 等）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOGIC_ROOT="$ROOT/api/internal/logic"
HANDLER_ROOT="$ROOT/api/internal/handler"
removed=0

# 从 canonical 合并文件中收集 Logic 类型，删除同 package 下含 todo 的重复单文件。
prune_canonical_file_dupes() {
  local canonical="$1"
  [[ -f "$canonical" ]] || return 0
  local dir base f t ct
  dir="$(dirname "$canonical")"
  while IFS= read -r ct; do
    [[ -n "$ct" ]] || continue
    for f in "$dir"/*.go; do
      [[ -f "$f" ]] || continue
      [[ "$f" == "$canonical" ]] && continue
      base="$(basename "$f")"
      grep -q 'todo: add your logic' "$f" || continue
      t="$(grep -m1 -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//')"
      [[ "$t" == "$ct" ]] || continue
      echo "prune-api-logic-shells: remove $base (duplicate $t in $(basename "$canonical"))"
      rm -f "$f"
      removed=$((removed + 1))
    done
  done < <(grep -E '^type [A-Za-z0-9_]+Logic struct' "$canonical" | sed 's/type //;s/ struct.*//')
}

prune_unreferenced_todo_shells() {
  local f logic_type ctor
  while IFS= read -r f; do
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
  done < <(find "$LOGIC_ROOT" -name '*logic.go' -type f 2>/dev/null)
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

# 合并实现 SSOT（勿把业务抄进 goctl 单文件壳）
for canon in \
  "$LOGIC_ROOT/admin/admin_insights_logic.go" \
  "$LOGIC_ROOT/admin/admin_moe_flow_logic.go" \
  "$LOGIC_ROOT/ai/resource_logic.go" \
  "$LOGIC_ROOT/ai/agent_resources_logic.go" \
  "$LOGIC_ROOT/ai/lorebook_resources_logic.go" \
  "$LOGIC_ROOT/ai/provider_resources_logic.go"; do
  prune_canonical_file_dupes "$canon"
done

prune_unreferenced_todo_shells
prune_manifest_stubs
echo "prune-api-logic-shells: removed $removed file(s)"
