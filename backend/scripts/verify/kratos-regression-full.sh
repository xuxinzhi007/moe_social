#!/usr/bin/env bash
# 发版 / 大批合并：Kratos 门禁 + 业务 F 全量回归。
set -euo pipefail
V="$(cd "$(dirname "$0")" && pwd)"

bash "$V/kratos-regression.sh"
bash "$V/sprint/regression.sh"

echo "OK: verify/kratos-regression-full"
