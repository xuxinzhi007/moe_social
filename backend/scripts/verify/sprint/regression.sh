#!/usr/bin/env bash
# F70–F100d 业务迁移全量回归（Hybrid biz+gw；与 Kratos 传输正交）。
set -euo pipefail
# shellcheck disable=SC1091
source "20 20 12 61 79 80 81 701 33 98 100 204 250 395 398 399 400dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "20 20 12 61 79 80 81 701 33 98 100 204 250 395 398 399 400dirname "$0")"
S="$(cd "$(dirname "$0")" && pwd)"

run() { bash "$S/$1"; }

run f102-admin-memory.sh
run f101-admin.sh
run f103-llm-inference.sh
run f100d-community.sh
run f100c-admin-gifts-write.sh
run f100c-admin-gifts-ro.sh
run f100b-llm.sh
run f100a-gift.sh
run f99-community-checkin.sh
run f98-achievement-pkg.sh
run f97-admin-announcements-write.sh
run f96-social-mutate.sh
run f94-social-like.sh
run f92-social-write.sh
run f90.sh
run f80.sh
run f70.sh

echo "OK: verify/sprint/regression"
