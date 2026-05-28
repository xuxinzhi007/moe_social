#!/usr/bin/env bash
# Sprint F80 回归：U1 + A1 + P1
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

bash "$(dirname "$0")/f80-u1.sh"
bash "$(dirname "$0")/f80-a1.sh"
bash "$(dirname "$0")/f80-p1.sh"

echo "OK: Sprint F80 verified"
