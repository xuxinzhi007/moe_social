#!/usr/bin/env bash
# 每个 PK / 域迁移 PR 必跑：PK 门禁 + 试点/Hybrid 回归（轻量，不含 F 全量）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== verify-kratos-rollout-regression (light) =="

bash scripts/verify-kratos-rollout-pk34.sh
bash scripts/verify-kratos-pure-100.sh
bash scripts/verify-kratos-rollout-pk11.sh
bash scripts/verify-sprint-fs9b.sh
bash scripts/verify-sprint-fs9.sh

echo "OK: PK regression light (pk34 + kratos-100 + fs9)"
