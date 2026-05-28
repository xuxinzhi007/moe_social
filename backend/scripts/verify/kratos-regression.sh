#!/usr/bin/env bash
# PK / Kratos 相关 PR 轻量回归（不含 F 全量）。
set -euo pipefail
V="$(cd "$(dirname "$0")" && pwd)"

bash "$V/kratos-pure-100.sh"
bash "$V/fs9b.sh"

echo "OK: verify/kratos-regression (pure-100 + fs9b; full FS-9: make verify-sprint-fs9)"
