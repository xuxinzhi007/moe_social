#!/usr/bin/env bash
# Moe Admin：moe-social（单进程 Kratos HTTP :8888）+ Agent + Moe Admin 开发服

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

start_bg moe-social "cd '$BACKEND' && go run ./cmd/moe-social -f config/config.yaml -migrate"
sleep 2
start_bg agent "cd '$BACKEND' && go run ./cmd/deploy-agent -f deploy/config.yaml"
start_bg vite "cd '$MOE_ADMIN' && ( [ -d node_modules ] || npm ci ) && npm run dev"

echo ""
echo "后端:   http://127.0.0.1:8888/health"
echo "管理台: http://127.0.0.1:5173/ops/login"
echo "Agent:  http://127.0.0.1:19010/"
echo "日志:   $RUN_DIR/*.log（后台启动失败不会中断本脚本，起不来时先看这里）"
echo "停止: ./scripts/stop-admin.sh"
