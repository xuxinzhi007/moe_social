#!/usr/bin/env bash
# 扫描 api/**/v1/*.proto → backend/api/<domain>/v1/*.pb.go（module=backend）
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v protoc >/dev/null 2>&1; then
  echo "protoc 未安装，跳过 gen-moe-proto（可选）" >&2
  exit 0
fi

count=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "protoc: $f"
  protoc \
    --proto_path=. \
    --go_out=. --go_opt=module=backend \
    --go-grpc_out=. --go-grpc_opt=module=backend \
    "$f"
  count=$((count + 1))
done < <(find api -path '*/v1/*.proto' 2>/dev/null | sort)

if [ "$count" -eq 0 ]; then
  echo "no api/**/v1/*.proto found"
  exit 0
fi
echo "OK: gen-moe-proto (${count} file(s)) → backend/api/*/v1/*.pb.go"
