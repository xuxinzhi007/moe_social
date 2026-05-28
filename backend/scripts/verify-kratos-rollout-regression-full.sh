#!/usr/bin/env bash
# 发版 / 大批合并前：轻量 PK 回归 + F 全量 Hybrid 回归。
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/verify-kratos-rollout-regression.sh

echo "== verify-kratos-rollout-regression-full: sprint F70–F100d =="
bash scripts/verify-sprint-regression

echo "OK: PK + full Hybrid regression"
