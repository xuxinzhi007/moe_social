#!/usr/bin/env bash
# 停止 start-admin.sh 拉起的 moe-social / agent / vite

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

stop_pid moe-social
stop_pid agent
stop_pid vite
echo "完成。若 :8888 仍被占用（go run 子进程未随父进程退出），执行：cd backend && make moe-social-stop"
