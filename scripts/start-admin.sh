#!/usr/bin/env bash
# Moe Admin：RPC + API + Agent + Moe Admin 开发服

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="$ROOT/backend"
MOE_ADMIN="$ROOT/moe-admin"
RUN_DIR="$ROOT/.run/admin"
mkdir -p "$RUN_DIR"

echo "== Moe Admin 启动 =="

start_bg() {
  local name="$1"
  local cmd="$2"
  local pidfile="$RUN_DIR/${name}.pid"
  local logfile="$RUN_DIR/${name}.log"
  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "跳过 $name（已在运行）"
    return
  fi
  echo "启动 $name ..."
  bash -lc "$cmd" >>"$logfile" 2>&1 &
  echo $! >"$pidfile"
}

start_bg rpc "cd '$BACKEND' && go run ./rpc/super.go -f rpc/etc/moe.yaml -migrate"
sleep 2
start_bg api "cd '$BACKEND' && go run ./api/super.go -f api/etc/moe.yaml"
sleep 2
start_bg agent "cd '$BACKEND' && go run ./cmd/deploy-agent -f deploy/config.yaml"
start_bg vite "cd '$MOE_ADMIN' && ( [ -d node_modules ] || npm ci ) && npm run dev"

echo ""
echo "管理台: http://127.0.0.1:5173/ops/login"
echo "Agent:  http://127.0.0.1:19010/"
echo "停止: ./scripts/stop-admin.sh"
