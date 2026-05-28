#!/usr/bin/env bash
# gen-moe-admin：在 make gen 之后删除与合并 logic 冲突的 goctl 空壳，并编译校验。
# 用法（在 backend 目录）: ./scripts/gen-moe-admin.sh [--skip-gen]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_GEN=0
if [[ "${1:-}" == "--skip-gen" ]]; then
  SKIP_GEN=1
fi

if [[ "$SKIP_GEN" -eq 0 ]]; then
  echo "==> make gen-rpc gen-api"
  make gen-rpc gen-api
fi

# prune 脚本已处理 RPC/API 空壳；此处仅删已知错误合并的 handler
MOE_API_STUBS=(
  api/internal/handler/admin/adminrefinemoebrainhandler.go
)

removed=0
for f in "${MOE_API_STUBS[@]}"; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    echo "removed stub: $f"
    removed=$((removed + 1))
  fi
done

bash scripts/verify-gen-hygiene.sh

echo "==> go build ./api ./rpc"
go build -o /dev/null ./api ./rpc

echo "OK: gen-moe-admin finished (removed $removed stub file(s))"
