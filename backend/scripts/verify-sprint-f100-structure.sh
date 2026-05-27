#!/usr/bin/env bash
# Sprint F100 结构验收：全域 GW 已接线 + biz 包存在 + 编译
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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

bash scripts/verify-sprint-f70.sh
bash scripts/verify-sprint-f80.sh
bash scripts/verify-sprint-f90.sh

go build -o /dev/null ./cmd/moe-social ./cmd/moe-social-stack
echo "OK: F100 structure gate (Hybrid GW + biz layers)"
