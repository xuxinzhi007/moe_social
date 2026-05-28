#!/usr/bin/env bash
# Sprint S2：User GetVipOrders → biz/user 验收
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-s2-user-vip =="

test -f internal/biz/user/vip_orders.go
grep -q 'func ListVipOrders' internal/biz/user/vip_orders.go
grep -q 'GetVipOrders' internal/service/user/app.go
grep -q 'func (g \*Gateway) GetVipOrders' api/internal/usergw/gateway.go
grep -q 'UserGW.GetVipOrders' api/internal/logic/user/getviporderslogic.go
grep -q 'userbiz.ListVipOrders' rpc/internal/logic/getviporderslogic.go

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/user/... ./internal/service/user/... ./cmd/moe-social

echo "OK: User VIP orders in_process wired"
