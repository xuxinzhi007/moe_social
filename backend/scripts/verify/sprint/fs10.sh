#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "20 20 12 61 79 80 81 701 33 98 100 204 250 395 398 399 400dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "20 20 12 61 79 80 81 701 33 98 100 204 250 395 398 399 400dirname "$0")"
D="$(cd "$(dirname "$0")" && pwd)"
bash "$D/fs10-admin-rpc.sh"
bash "$D/fs10-rpc-thin.sh"
