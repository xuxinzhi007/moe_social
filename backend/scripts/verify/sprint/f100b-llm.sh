#!/usr/bin/env bash
# F100b：LLM 域 models/catalog/chat-turn → biz + llmgw
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../../lib/backend-root.sh"
moe_backend_cd "$(dirname "$0")"

echo "== verify-sprint-f100b-llm =="

test -f internal/biz/llm/models.go
test -f internal/biz/llm/chat_turn.go
test -f internal/service/llm/app.go
test -f api/internal/llmgw/gateway.go
grep -q 'LLMApp.ListModels' api/internal/logic/llm/modelslogic.go
grep -q 'LLMApp.LocalCatalog' api/internal/logic/llm/localmodelscataloglogic.go
grep -q 'LLMGW.RecordLlmChatTurn' api/internal/logic/llm/chat_persist.go
grep -q 'LLMGW.GetUserMemories' api/internal/logic/llm/chatlogic.go
grep -q 'llmbiz.RecordChatTurn' rpc/internal/logic/recordllmchatturnlogic.go
grep -q 'llm_api_in_process' config/config.yaml

go build -o /dev/null ./api/... ./rpc/... ./internal/biz/llm/... ./internal/service/llm/... ./cmd/moe-social
echo "OK: llm domain in_process (F100b)"
