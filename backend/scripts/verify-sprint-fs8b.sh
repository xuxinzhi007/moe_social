#!/usr/bin/env bash
# FS-8b: RPC 契约按域分片 + 组装 + 回归（含 FS-8 HTTP / FS-10 RPC 薄层）
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

echo "== verify-sprint-fs8b =="

test -f rpc/defs/common.proto
test -f rpc/defs/services/user.rpcfrag
test -f scripts/fs8-rpc-domain-rules.json

# moe.proto 仅为入口 + service（message 在 common）
if grep -qE '^message ' rpc/moe.proto; then
  echo "FS-8b: rpc/moe.proto must not contain message (use defs/common.proto)"
  exit 1
fi

python3 scripts/fs8-assemble-super-proto.py

cd rpc
protoc --proto_path=. --descriptor_set_out=/dev/null defs/common.proto moe.proto

rpc_count=$(grep -cE '^\s+rpc ' moe.proto || true)
frag_sum=0
for f in defs/services/*.rpcfrag; do
  c=$(grep -cE '^\s*rpc ' "$f" 2>/dev/null || echo 0)
  frag_sum=$((frag_sum + c))
done
if [ "$rpc_count" -ne "$frag_sum" ]; then
  echo "FS-8b: rpc count mismatch super=$rpc_count frags=$frag_sum"
  exit 1
fi

cd "$root"
make gen-rpc >/dev/null
go build ./api ./rpc
go build -o /dev/null ./cmd/moe-social ./cmd/moe-social-stack

bash scripts/verify-sprint-fs8.sh
make verify-sprint-fs10

echo "OK: FS-8b RPC domain shards + HTTP FS-8 + FS-10 regression"
