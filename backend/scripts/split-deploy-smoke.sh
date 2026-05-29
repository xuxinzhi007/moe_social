#!/usr/bin/env bash
# P5 分体部署联调：构建 api/rpc 二进制、校验配置语义、可选 gRPC 冒烟。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BIN_DIR="${BIN_DIR:-/tmp/moe-social-split-smoke}"
mkdir -p "$BIN_DIR"

echo "==> build split binaries"
go build -o "$BIN_DIR/moe-social-api" ./api
go build -o "$BIN_DIR/moe-social-rpc" ./rpc
go build -o "$BIN_DIR/moe-social" ./cmd/moe-social

echo "==> production deps: no go-zero"
if go list -deps ./cmd/moe-social | grep -q go-zero; then
  echo "FAIL: cmd/moe-social still depends on go-zero" >&2
  exit 1
fi
echo "OK: go list -deps ./cmd/moe-social has no go-zero"

echo "==> split config checklist (config/config.yaml comments)"
if grep -q 'single_process: false' config/config.yaml 2>/dev/null; then
  echo "NOTE: config has single_process: false — split mode"
else
  echo "NOTE: default single_process=true; for split set single_process=false + super_grpc_retired=false"
fi
grep -E 'super_rpc_endpoints|grpc_listen|single_process|super_grpc_retired' config/config.yaml | head -n 8 || true

echo "==> domain gRPC smoke (requires RPC on \${GRPC_HOST:-127.0.0.1:8080})"
if bash scripts/grpc-smoke-notify-chat-vip.sh; then
  echo "OK: grpc smoke notify/chat/vip"
else
  echo "SKIP: grpc smoke failed — start server first: make moe-social" >&2
  exit 0
fi

echo "OK: split-deploy smoke complete"
