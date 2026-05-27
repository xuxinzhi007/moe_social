#!/usr/bin/env bash
# 纯 Kratos 试点 gRPC 探针（需先 make moe-kratos）
# 依赖: grpcurl (brew install grpcurl)
set -euo pipefail

HOST="${MOE_KRATOS_GRPC:-127.0.0.1:19031}"

if ! command -v grpcurl >/dev/null 2>&1; then
  echo "grpcurl 未安装，跳过（brew install grpcurl）" >&2
  exit 0
fi

echo "== list services (reflection) @ ${HOST} =="
grpcurl -plaintext "${HOST}" list

echo ""
echo "== moe.v1.MoeAdmin/ListRuntimes =="
grpcurl -plaintext -d '{}' "${HOST}" moe.v1.MoeAdmin/ListRuntimes

echo ""
echo "OK: grpcurl moe-kratos"
