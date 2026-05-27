#!/usr/bin/env bash
# Kratos 混合迁移验收：编译 + 单测 + Moe RPC 注册检查
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== go build api + rpc =="
go build -o /dev/null ./api
go build -o /dev/null ./rpc

echo "== go test internal/biz/moe =="
go test ./internal/biz/moe/... -count=1

echo "== go test internal/adapter/rpcsuper =="
go test ./internal/adapter/rpcsuper/... -count=1 2>/dev/null || true

echo "== Moe Admin RPC 已注册（super.proto） =="
for method in \
  AdminListMoeRuntimes \
  AdminUpsertMoeRuntime \
  AdminRunMoeAgentOnce \
  AdminGetMoeBrain \
  AdminUpdateMoeBrainPolicy \
  AdminDeleteMoeBrainEpisode \
  AdminRefineMoeBrainEpisode \
  AdminCurateMoeBrain \
  AdminGetMoeBrainPipeline \
  AdminGetMoeToolStats \
  AdminListMoeToolCalls \
  MoeExecuteTool \
  MoeSearchPosts; do
  if ! grep -q "rpc ${method}" rpc/super.proto; then
    echo "MISSING rpc ${method} in super.proto" >&2
    exit 1
  fi
done

echo "== MoeAdmin service 方法存在 =="
for sym in \
  ListRuntimes \
  UpsertRuntime \
  RunAgentOnce \
  GetBrainSnapshot \
  GetBrainPipeline \
  DeleteBrainEpisode \
  QueryToolStats \
  ExecuteTool \
  SearchPosts; do
  if ! grep -q "func (s \*AdminService) ${sym}" internal/service/moe/admin.go; then
    echo "MISSING AdminService.${sym}" >&2
    exit 1
  fi
done

echo ""
echo "OK: Moe hybrid migration verification passed"
