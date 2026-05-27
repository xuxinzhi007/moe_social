#!/usr/bin/env bash
# internal/conf/**/v1/*.proto → 同目录 *.pb.go
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v protoc >/dev/null 2>&1; then
  echo "protoc 未安装，跳过 gen-moe-conf" >&2
  exit 0
fi

count=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "protoc: $f"
  protoc \
    --proto_path=. \
    --go_out=. --go_opt=module=backend \
    "$f"
  count=$((count + 1))
done < <(find internal/conf -path '*/v1/*.proto' 2>/dev/null | sort)

if [ "$count" -eq 0 ]; then
  echo "no internal/conf/**/v1/*.proto found"
  exit 0
fi
echo "OK: gen-moe-conf (${count} file(s))"
