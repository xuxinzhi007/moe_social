#!/usr/bin/env bash
# 兼容别名：完整纯 Kratos >= 80%（生产 moe-social，非 :1903x 试点）。
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-kratos-pure-80.sh
