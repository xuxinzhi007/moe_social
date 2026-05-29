#!/usr/bin/env bash
# Moe Admin：proto 生成 + 编译校验（无 goctl）。
set -euo pipefail
cd "$(dirname "$0")/../.."

if [[ "${1:-}" != "--skip-gen" ]]; then
  make gen
fi

go build -o /dev/null ./cmd/moe-social
echo "OK: gen-moe-admin (proto + cmd/moe-social)"
