package llmapp

import (
	"errors"
	"net/http"

	llmbiz "backend/internal/biz/llm"
)

// ConfigAPIPayload 返回 GET /api/llm/config 的 data 字段。
func (s *AppService) ConfigAPIPayload() map[string]interface{} {
	if s == nil {
		return llmbiz.ConfigAPIPayload(llmbiz.ConfigSnapshot{})
	}
	return llmbiz.ConfigAPIPayload(s.ConfigSnapshot())
}

// ForwardChatRaw 流式转发 chat 请求到推理服务。
func (s *AppService) ForwardChatRaw(w http.ResponseWriter, r *http.Request) error {
	if s == nil {
		return errors.New("llm app unavailable")
	}
	return llmbiz.ForwardChatRaw(w, r, s.deps.Inference)
}

// ForwardModelsRaw 转发 Ollama /api/tags。
func (s *AppService) ForwardModelsRaw(w http.ResponseWriter, r *http.Request) error {
	if s == nil {
		return errors.New("llm app unavailable")
	}
	return llmbiz.ForwardModelsRaw(w, r, s.deps.Inference)
}

// ForwardShowRaw 转发 Ollama /api/show。
func (s *AppService) ForwardShowRaw(w http.ResponseWriter, r *http.Request) error {
	if s == nil {
		return errors.New("llm app unavailable")
	}
	return llmbiz.ForwardShowRaw(w, r, s.deps.Inference)
}
