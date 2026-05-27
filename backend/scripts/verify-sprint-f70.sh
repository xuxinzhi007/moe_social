#!/usr/bin/env bash
# Sprint F70 批次回归：S1 + S2 + S3 + full-site-50
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f70 =="

bash scripts/verify-sprint-s1-landing.sh
bash scripts/verify-sprint-s2-user-vip.sh
bash scripts/verify-sprint-s3-admin-ro.sh
bash scripts/verify-sprint-s4-misc.sh
bash scripts/verify-sprint-s5-notify.sh
bash scripts/verify-full-site-50.sh

echo "OK: Sprint F70 batch verified"
