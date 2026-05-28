#!/usr/bin/env bash
# Sprint F100 结构验收：全域 GW 已接线 + biz 包存在 + 编译
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f100-structure =="

for f in \
  api/internal/moeadmingw/gateway.go \
  api/internal/vipadmingw/gateway.go \
  api/internal/usergw/gateway.go \
  api/internal/landinggw/gateway.go \
  api/internal/admingw/gateway.go \
  api/internal/behaviorgw/gateway.go \
  api/internal/postgw/gateway.go \
  api/internal/commentgw/gateway.go \
  api/internal/checkinwg/gateway.go \
  api/internal/achievementgw/gateway.go \
  api/internal/giftgw/gateway.go \
  api/internal/llmgw/gateway.go \
  api/internal/communitygw/gateway.go
do
  test -f "$f"
done

test -d internal/biz/moe
test -d internal/biz/post
test -d internal/biz/comment
test -d internal/biz/notify
test -d internal/biz/admin
test -d internal/biz/llm
test -d internal/biz/community

bash "$(dirname "$0")/f70.sh"
bash "$(dirname "$0")/f80.sh"
bash "$(dirname "$0")/f90.sh"

go build -o /dev/null ./cmd/moe-social ./cmd/moe-social-stack
echo "OK: F100 structure gate (Hybrid GW + biz layers)"
