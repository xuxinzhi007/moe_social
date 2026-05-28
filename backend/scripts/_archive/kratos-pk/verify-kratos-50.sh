#!/usr/bin/env bash
# 兼容别名：完整纯 Kratos >= 50%（见 verify-kratos-pure-50）。
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-kratos-pure-50.sh
