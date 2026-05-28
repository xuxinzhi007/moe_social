#!/usr/bin/env bash
# 生成后检查：无未引用 goctl todo 空壳。
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

if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "OK: post-gen check"
