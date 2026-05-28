#!/usr/bin/env bash
# Moe Admin 生成后清理空壳并编译校验。
set -euo pipefail
cd "$(dirname "$0")/../.."

SKIP_GEN=0
if [[ "${1:-}" == "--skip-gen" ]]; then
  SKIP_GEN=1
fi

if [[ "$SKIP_GEN" -eq 0 ]]; then
  make gen-rpc gen-api
fi

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

bash scripts/gen/post-gen-check.sh
go build -o /dev/null ./api ./rpc

echo "OK: gen/moe-admin (removed $removed stub file(s))"
