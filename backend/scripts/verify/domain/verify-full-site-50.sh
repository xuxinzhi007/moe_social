#!/usr/bin/env bash
# 全站迁移 F≈50% 验收（Hybrid 回归 + 域脚本）
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"
cd "$ROOT"

echo "== verify-full-site-50 =="

bash "$(dirname "$0")/verify-moe-complete.sh
bash "$(dirname "$0")/verify-domain-vip.sh
bash "$(dirname "$0")/verify-domain-user.sh
bash "$(dirname "$0")/verify-domain-misc.sh
bash "$(dirname "$0")/verify-platform.sh"

go build -o /dev/null ./cmd/moe-social

echo "OK: full-site ~50% milestones (see docs/dev/kratos-full-site-migration-plan.md §1.5)"
