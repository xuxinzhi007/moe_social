#!/usr/bin/env bash
# 全站迁移 F≈50% 验收（Hybrid 回归 + 域脚本）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-full-site-50 =="

bash scripts/verify-moe-complete.sh
bash scripts/verify-domain-vip.sh
bash scripts/verify-domain-user.sh
bash scripts/verify-platform.sh

go build -o /dev/null ./cmd/moe-social

echo "OK: full-site ~50% milestones (see docs/dev/kratos-full-site-migration-plan.md §1.5)"
