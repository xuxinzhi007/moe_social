#!/usr/bin/env bash
# 发版飞书卡片。状态：building / failed / success。
# 缺任一飞书 Secret 时跳过，不让打包变红。
set -euo pipefail

STATUS="${1:-}"
if [ -z "${FEISHU_APP_ID:-}" ] || [ -z "${FEISHU_APP_SECRET:-}" ] || [ -z "${FEISHU_NOTIFY_EMAIL:-}" ]; then
  echo "Skip Feishu notify: set Secrets FEISHU_APP_ID / FEISHU_APP_SECRET / FEISHU_NOTIFY_EMAIL"
  exit 0
fi

TAG="${RELEASE_TAG:-未知版本}"
NAME="${VERSION_NAME:-未知}"
CODE="${VERSION_CODE:-未知}"
RUN_URL="${RUN_URL:-}"
APK_URL="${APK_URL:-}"
RELEASE_URL="${RELEASE_URL:-}"

case "$STATUS" in
  building)
    TITLE="Moe Social ${TAG} 打包中"
    TEMPLATE="blue"
    BODY=$(printf '版本 %s（versionCode %s）开始打包。\n[查看本次 Actions](%s)' "$NAME" "$CODE" "$RUN_URL")
    ;;
  failed)
    TITLE="Moe Social ${TAG} 打包失败"
    TEMPLATE="red"
    BODY=$(printf '版本 %s（versionCode %s）打包失败。\n[查看失败日志](%s)' "$NAME" "$CODE" "$RUN_URL")
    ;;
  success)
    TITLE="Moe Social ${TAG} 打包成功"
    TEMPLATE="green"
    BODY=$(printf '版本 %s（versionCode %s）已上传。\n[下载 APK](%s)\n[GitHub Release](%s)\n[查看 Actions](%s)' \
      "$NAME" "$CODE" "$APK_URL" "$RELEASE_URL" "$RUN_URL")
    ;;
  *)
    echo "unknown feishu status: ${STATUS}"
    exit 1
    ;;
esac

echo "Notify ${FEISHU_NOTIFY_EMAIL}: ${TITLE}"

TOKEN_JSON=$(curl -sS --connect-timeout 10 --max-time 30 \
  -X POST 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' \
  -H 'Content-Type: application/json' \
  -d "$(jq -cn --arg id "$FEISHU_APP_ID" --arg secret "$FEISHU_APP_SECRET" '{app_id:$id,app_secret:$secret}')")
TOKEN=$(echo "$TOKEN_JSON" | jq -r '.tenant_access_token // empty')
CODE_RESP=$(echo "$TOKEN_JSON" | jq -r '.code // -1')
if [ -z "$TOKEN" ] || [ "$CODE_RESP" != "0" ]; then
  echo "Feishu token failed:"
  echo "$TOKEN_JSON" | jq 'del(.tenant_access_token)' || echo "$TOKEN_JSON"
  exit 1
fi

CARD=$(jq -cn \
  --arg title "$TITLE" \
  --arg template "$TEMPLATE" \
  --arg body "$BODY" \
  '{
    config: {wide_screen_mode: true},
    header: {title: {tag: "plain_text", content: $title}, template: $template},
    elements: [{tag: "div", text: {tag: "lark_md", content: $body}}]
  }')
BODY_JSON=$(jq -cn \
  --arg receive_id "$FEISHU_NOTIFY_EMAIL" \
  --arg content "$CARD" \
  '{receive_id:$receive_id, msg_type:"interactive", content:$content}')

RESP=$(curl -sS --connect-timeout 10 --max-time 30 \
  -X POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=email' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "$BODY_JSON")
MSG_CODE=$(echo "$RESP" | jq -r '.code // -1')
if [ "$MSG_CODE" != "0" ]; then
  echo "Feishu message failed:"
  echo "$RESP" | jq . || echo "$RESP"
  exit 1
fi
echo "Feishu notify OK: ${STATUS}"
