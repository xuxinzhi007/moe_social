#!/usr/bin/env bash
# 全站 Kratos 对齐 ≥70%（PK-0～3 + 进度口径）。
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-rollout-pk12.sh
bash scripts/verify-kratos-rollout-pk3.sh

go test ./internal/platform/kratosprogress/... -count=1 -run TestCompletePureKratosAtLeast80

echo "OK: Kratos migration rollout >= 70% (team metric)"
