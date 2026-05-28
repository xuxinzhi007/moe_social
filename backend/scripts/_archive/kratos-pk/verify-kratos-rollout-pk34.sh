#!/usr/bin/env bash
# PK-3 + PK-4 完整验收（≥85% 团队口径）。
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-rollout-pk3.sh
bash scripts/verify-kratos-rollout-pk4.sh
bash scripts/verify-kratos-rollout-pk6.sh
bash scripts/verify-kratos-rollout-pk7.sh

echo "OK: Kratos migration rollout PK-3/4/6/7"
