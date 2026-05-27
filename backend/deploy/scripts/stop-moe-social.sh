#!/usr/bin/env bash
# 释放 make moe-social / make dev 占用的开发端口（macOS / Linux）
set -euo pipefail

ports=(8080 8888 19010 19011 19012)
killed=()

kill_port() {
  local port=$1
  if ! command -v lsof >/dev/null 2>&1; then
    echo "lsof not found; install lsof or use Windows stop-moe-social.ps1" >&2
    exit 1
  fi
  while read -r pid; do
    [[ -z "$pid" || "$pid" == "0" ]] && continue
    for k in "${killed[@]:-}"; do
      [[ "$k" == "$pid" ]] && continue 2
    done
    echo "Stopping PID $pid (port $port)..."
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.2
    kill -KILL "$pid" 2>/dev/null || true
    killed+=("$pid")
  done < <(lsof -ti ":$port" -sTCP:LISTEN 2>/dev/null || true)
}

for p in "${ports[@]}"; do
  kill_port "$p"
done

still=()
for p in "${ports[@]}"; do
  if lsof -ti ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
    still+=("$p")
  fi
done

if ((${#still[@]} > 0)); then
  echo "WARN: ports still in use: ${still[*]}"
  exit 1
fi

echo "moe-social dev ports cleared (8080, 8888, 19010, 19011, 19012)"
