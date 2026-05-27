#!/usr/bin/env bash
# F102：Admin 写 CRUD + LLM memory 写路径 biz 化
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f102-admin-memory =="

test -f internal/biz/admin/users_write.go
test -f internal/biz/admin/menus_write.go
test -f internal/biz/llm/memory_write.go
grep -q 'AdminGW.AdminUpdateUser' api/internal/logic/admin/adminupdateuserlogic.go
grep -q 'AdminGW.AdminUpsertMenu' api/internal/logic/admin/adminupsertmenulogic.go
grep -q 'LLMGW.UpsertUserMemory' api/internal/logic/user/upsertusermemorylogic.go
grep -q 'llmbiz.UpsertUserMemory' rpc/internal/logic/upsertusermemorylogic.go
grep -q 'local.UpsertUserMemory' api/internal/llmgw/gateway.go

go test ./internal/biz/admin/... ./internal/biz/llm/... -count=1
go build -o /dev/null ./api/... ./rpc/... ./internal/biz/admin/... ./internal/biz/llm/... ./internal/service/admin/... ./internal/service/llm/...
echo "OK: F102 admin write + memory write in_process"
