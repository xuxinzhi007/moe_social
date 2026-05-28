#!/usr/bin/env bash
# P3 完成后：goctl gen-api 仍会生成 logic 空壳；生产已退役 logic 层，统一删除。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOGIC_ROOT="$ROOT/api/internal/logic"
removed=0

if [[ ! -d "$LOGIC_ROOT" ]]; then
  echo "prune-api-logic-retired: logic dir absent, skip"
  exit 0
fi

while IFS= read -r f; do
  rm -f "$f"
  removed=$((removed + 1))
done < <(find "$LOGIC_ROOT" -name '*.go' -type f 2>/dev/null)

# 保留空目录 + .gitkeep 供 goctl 路径稳定
touch "$LOGIC_ROOT/.gitkeep"

echo "prune-api-logic-retired: removed $removed logic .go file(s) (P3 retired; handlers use GW/biz)"
