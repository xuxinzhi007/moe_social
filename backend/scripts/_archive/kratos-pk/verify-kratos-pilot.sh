#!/usr/bin/env bash
# 已废弃：试点进程收敛到 make moe-social。仅保留 build 检查。
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== verify-kratos-pilot (deprecated → moe-social) =="
bash scripts/verify-kratos-pure-50.sh
echo "OK: use make moe-social (:8888); moe-kratos :1903x is deprecated"
