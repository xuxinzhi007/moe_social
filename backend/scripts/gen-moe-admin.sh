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

# 与 rpc/internal/logic/moe_admin_logic.go 合并实现冲突的空壳（make gen-rpc 会再生，需再删）
MOE_RPC_STUBS=(
  rpc/internal/logic/admingetmoebrainlogic.go
  rpc/internal/logic/adminupdatemoebrainpolicylogic.go
  rpc/internal/logic/adminrefinemoebrainepisodelogic.go
  rpc/internal/logic/admingetmoetoolstatslogic.go
  rpc/internal/logic/adminlistmoeruntimeslogic.go
  rpc/internal/logic/admincuratemoebrainlogic.go
  rpc/internal/logic/adminrunmoeagentoncelogic.go
  rpc/internal/logic/adminupsertmoeruntimelogic.go
  rpc/internal/logic/admindeletemoebrainepisodelogic.go
  rpc/internal/logic/adminlistmoetoolcallslogic.go
  rpc/internal/logic/moeexecutetoollogic.go
  rpc/internal/logic/moesearchpostslogic.go
)

# API：错误合并的 handler（两个 handler 写进一个文件）
MOE_API_STUBS=(
  api/internal/handler/admin/adminrefinemoebrainhandler.go
)

removed=0
for f in "${MOE_RPC_STUBS[@]}" "${MOE_API_STUBS[@]}"; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    echo "removed stub: $f"
    removed=$((removed + 1))
  fi
done

echo "==> go build ./api ./rpc"
go build -o /dev/null ./api ./rpc

echo "OK: gen-moe-admin finished (removed $removed stub file(s))"
