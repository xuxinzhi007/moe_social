#!/usr/bin/env bash
# One ordered pipeline for Go contracts and OpenAPI; never installs tools.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/../.."
source scripts/gen/proto-tools.sh

output=$PWD
mode=all
single_proto=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output=${2:?--output requires an existing directory}; shift 2 ;;
    --openapi-only) mode=openapi; shift ;;
    --proto) mode=proto; single_proto=${2:?--proto requires a file}; shift 2 ;;
    *) proto_error "unknown argument: $1"; exit 1 ;;
  esac
done
[[ -d "$output" ]] || { proto_error "output directory does not exist: $output"; exit 1; }
output=$(cd "$output" && pwd)

# Check every plugin before writing even the first output.
proto_check_tools
proto_list=$(find api -type f -path '*/v1/*.proto' | sort)
[[ -n "$proto_list" ]] || { proto_error 'no api/**/v1/*.proto found'; exit 1; }
proto_files=()
while IFS= read -r file; do
  proto_files+=("$file")
done <<< "$proto_list"
if [[ "$mode" == proto ]]; then
  found=false
  for file in "${proto_files[@]}"; do
    [[ "$file" != "$single_proto" ]] || found=true
  done
  "$found" || { proto_error "not a current api/**/v1/*.proto input: $single_proto"; exit 1; }
  proto_files=("$single_proto")
fi

if [[ "$mode" != openapi ]]; then
  for file in "${proto_files[@]}"; do
    printf 'protoc: %s\n' "$file"
    "$PROTOC_BINARY" \
      --proto_path=. --proto_path=./third_party \
      "--plugin=protoc-gen-go=${PLUGIN_BINARIES[0]}" \
      "--plugin=protoc-gen-go-grpc=${PLUGIN_BINARIES[1]}" \
      "--plugin=protoc-gen-go-http=${PLUGIN_BINARIES[2]}" \
      "--go_out=$output" --go_opt=module=backend \
      "--go-grpc_out=$output" --go-grpc_opt=module=backend \
      "--go-http_out=$output" --go-http_opt=module=backend \
      "$file"
  done
fi
if [[ "$mode" != proto ]]; then
  "$PROTOC_BINARY" \
    --proto_path=. --proto_path=./third_party \
    "--plugin=protoc-gen-openapi=${PLUGIN_BINARIES[3]}" \
    "--openapi_out=fq_schema_naming=true,default_response=false:$output" \
    "${proto_files[@]}"
fi
printf 'OK: generated %s (%s proto inputs)\n' "$mode" "${#proto_files[@]}"
