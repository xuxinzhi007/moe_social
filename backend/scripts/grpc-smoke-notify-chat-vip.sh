#!/usr/bin/env bash
# P5 域 gRPC 冒烟：notify / chat / vip（需 RPC 监听 :8080，cwd=backend/）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HOST="${GRPC_HOST:-127.0.0.1:8080}"
USER_ID="${SMOKE_USER_ID:-smoke-user-1}"

if ! command -v grpcurl >/dev/null 2>&1; then
  echo "grpcurl not found; install: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest" >&2
  exit 1
fi

run() {
  local name="$1"
  shift
  echo "==> $name"
  grpcurl -plaintext "$@"
}

run "notify GetNotifications" \
  -import-path api -proto api/notify/v1/notify.proto \
  -d "{\"user_id\":\"${USER_ID}\",\"page\":1,\"page_size\":5}" \
  "$HOST" notify.v1.NotifyService/GetNotifications

run "notify GetUnreadCount" \
  -import-path api -proto api/notify/v1/notify.proto \
  -d "{\"user_id\":\"${USER_ID}\"}" \
  "$HOST" notify.v1.NotifyService/GetUnreadCount

run "chat ListPrivateConversations" \
  -import-path api -proto api/chat/v1/private_message.proto \
  -d "{\"user_id\":\"${USER_ID}\",\"limit\":10,\"offset\":0}" \
  "$HOST" chat.v1.PrivateMessageService/ListPrivateConversations

run "vip GetVipRecords" \
  -import-path api -proto api/vip/v1/vip.proto \
  -d "{\"user_id\":\"${USER_ID}\",\"page\":1,\"page_size\":5}" \
  "$HOST" vip.v1.VipService/GetVipRecords

run "vip GetUserActiveVipRecord" \
  -import-path api -proto api/vip/v1/vip.proto \
  -d "{\"user_id\":\"${USER_ID}\"}" \
  "$HOST" vip.v1.VipService/GetUserActiveVipRecord

echo "OK: grpc smoke notify/chat/vip @ ${HOST}"
