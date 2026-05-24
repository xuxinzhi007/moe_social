#!/usr/bin/env bash
# 停止 start-admin.sh 拉起的 RPC / API（网关在前台，Ctrl+C 即可）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/.run/admin"

stop_pid() {
  local name="$1"
  local file="$RUN_DIR/${name}.pid"
  if [[ -f "$file" ]]; then
    local pid
    pid="$(cat "$file")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "已停止 $name (pid $pid)"
    fi
    rm -f "$file"
  fi
}

stop_pid rpc
stop_pid api
stop_pid agent
stop_pid vite
echo "完成。"
