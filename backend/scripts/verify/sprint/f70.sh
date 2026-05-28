#!/usr/bin/env bash
# Sprint F70 批次回归：S1 + S2 + S3 + full-site-50
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f70 =="

bash "$(dirname "$0")/s1-landing.sh"
bash "$(dirname "$0")/s2-user-vip.sh"
bash "$(dirname "$0")/s3-admin-ro.sh"
bash "$(dirname "$0")/s4-misc.sh"
bash "$(dirname "$0")/s5-notify.sh"
bash "$(dirname "$0")/../domain/verify-full-site-50.sh"

echo "OK: Sprint F70 batch verified"
