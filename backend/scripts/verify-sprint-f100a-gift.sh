#!/usr/bin/env bash
# F100a：Gift 域读+写 → biz + giftgw
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f100a-gift =="

test -f internal/biz/gift/send.go
test -f internal/biz/gift/purchase.go
test -f api/internal/giftgw/gateway.go
grep -q 'GiftGW.SendGift' api/internal/logic/gift/sendgiftlogic.go
grep -q 'GiftGW.PurchaseGift' api/internal/logic/gift/purchasegiftlogic.go
grep -q 'GiftGW.GetGifts' api/internal/logic/gift/getgiftslogic.go
grep -q 'giftapp.New' rpc/internal/logic/sendgiftlogic.go
grep -q 'RegisterGiftSentAchievementHook' rpc/internal/bootstrap/social_hooks.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/gift/... ./cmd/moe-social
echo "OK: gift domain in_process"
