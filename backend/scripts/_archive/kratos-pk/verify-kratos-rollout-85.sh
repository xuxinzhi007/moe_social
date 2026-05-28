#!/usr/bin/env bash
# 全站 Kratos 对齐 ≥85%（PK-3 + PK-4）。
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-rollout-pk34.sh

echo "OK: Kratos migration rollout >= 85% (team metric)"
