#!/usr/bin/env bash
# PK-1 + PK-2 合并验收。
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-kratos-rollout-pk0.sh
bash scripts/verify-kratos-rollout-pk1.sh
bash scripts/verify-kratos-rollout-pk2.sh
echo "OK: PK-1 + PK-2 complete"
