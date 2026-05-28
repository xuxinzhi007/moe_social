#!/usr/bin/env bash
# 生成后检查：无 todo 空壳；同 package 无重复 Logic 类型名。
set -euo pipefail
cd "$(dirname "$0")/../.."
bad=0

while IFS= read -r f; do
  logic_type="$(grep -m1 -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//')"
  [[ -n "$logic_type" ]] || continue
  ctor="New${logic_type}"
  if ! grep -rq "${ctor}(" api/internal/handler/ 2>/dev/null; then
    echo "orphan todo logic: ${f#$(pwd)/}"
    bad=1
  fi
done < <(grep -rl 'todo: add your logic' api/internal/logic --include='*logic.go' 2>/dev/null || true)

if grep -rq 'todo: add your logic' rpc/internal/logic --include='*.go' 2>/dev/null; then
  echo "rpc logic still has todo shells" >&2
  bad=1
fi

# 同 package 重复 Logic 类型（合并文件 + goctl 壳未 prune）
while IFS= read -r dir; do
  dupes="$(
    grep -h -E '^type [A-Za-z0-9_]+Logic struct' "$dir"/*.go 2>/dev/null \
      | sed 's/type //;s/ struct.*//' | sort | uniq -d
  )"
  [[ -z "$dupes" ]] && continue
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    echo "duplicate Logic type $t in ${dir#$(pwd)/}" >&2
    bad=1
  done <<< "$dupes"
done < <(find api/internal/logic -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "OK: post-gen check"
