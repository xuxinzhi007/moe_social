#!/usr/bin/env bash
# 兼容别名：完整纯 Kratos >= 50% + PK-11 门禁。
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-kratos-pure-50.sh
bash scripts/verify-kratos-rollout-pk11.sh
