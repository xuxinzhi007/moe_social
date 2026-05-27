#!/usr/bin/env bash
# Sprint F80 回归：U1 + A1 + P1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash scripts/verify-sprint-f80-u1.sh
bash scripts/verify-sprint-f80-a1.sh
bash scripts/verify-sprint-f80-p1.sh

echo "OK: Sprint F80 verified"
