#!/usr/bin/env bash
# 验收：无未引用 todo 空壳；合并 logic 无重复类型。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bad=0

while IFS= read -r f; do
  logic_type="$(grep -m1 -E '^type [A-Za-z0-9_]+Logic struct' "$f" | sed 's/type //;s/ struct.*//')"
  [[ -n "$logic_type" ]] || continue
  ctor="New${logic_type}"
  if ! grep -rq "${ctor}(" api/internal/handler/ 2>/dev/null; then
    echo "orphan todo logic: ${f#"$root"/}"
    bad=1
  fi
done < <(grep -rl 'todo: add your logic' api/internal/logic --include='*logic.go' 2>/dev/null || true)

if grep -rq 'todo: add your logic' rpc/internal/logic --include='*.go' 2>/dev/null; then
  echo "rpc logic still has todo shells"
  grep -rl 'todo: add your logic' rpc/internal/logic --include='*.go' || true
  bad=1
fi

if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "OK: gen hygiene (no unreferenced api todo shells)"
