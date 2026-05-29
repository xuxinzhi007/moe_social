#!/usr/bin/env bash
# 从 api/**/v1/*.proto 生成 OpenAPI 3.0（对齐 core-platform：protoc-gen-openapi）。
set -euo pipefail
cd "$(dirname "$0")/../.."

if ! command -v protoc >/dev/null 2>&1; then
  echo "protoc 未安装，跳过 OpenAPI 生成" >&2
  exit 0
fi

if ! command -v protoc-gen-openapi >/dev/null 2>&1; then
  echo "protoc-gen-openapi 未安装，自动执行 go install…" >&2
  go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest
fi

proto_files=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  proto_files+=("$f")
done < <(find api -path '*/v1/*.proto' 2>/dev/null | sort)

if [ "${#proto_files[@]}" -eq 0 ]; then
  echo "no api/**/v1/*.proto found"
  exit 0
fi

protoc \
  --proto_path=. \
  --proto_path=./third_party \
  --openapi_out=fq_schema_naming=true,default_response=false:. \
  "${proto_files[@]}"

path_count="$(grep -c '^    /' openapi.yaml || true)"
echo "generated backend/openapi.yaml (OpenAPI 3.0, ${path_count} paths)"
