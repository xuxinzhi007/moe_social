#!/usr/bin/env bash
# F103：LLM chat 推理 → biz/llm + LLMApp（App AI 聊天核心路径）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== verify-sprint-f103-llm-inference =="

test -f internal/biz/llm/inference.go
grep -q 'PostChatCompletion' internal/service/llm/app.go
grep -q 'llmbiz.PostChatCompletion' internal/biz/llm/inference.go
grep -q 'LLMApp.PostChatCompletion' api/internal/logic/llm/chat_inference_helpers.go
grep -q 'llm_api_in_process' config/config.yaml

go test ./internal/biz/llm/... -count=1
go build -o /dev/null ./api/... ./internal/biz/llm/... ./internal/service/llm/...
echo "OK: llm chat inference in_process (F103)"
