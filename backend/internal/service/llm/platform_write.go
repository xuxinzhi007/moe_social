package llmapp

import (
	"context"
	"errors"

	"backend/common/errorcode"
	llmbiz "backend/internal/biz/llm"
)

// CreateAgent 创建 Ollama 派生模型。
func (s *AppService) CreateAgent(ctx context.Context, in llmbiz.CreateAgentInput, cache llmbiz.ModelCacheClearer) llmbiz.PlatformWriteResult {
	if s == nil {
		return llmbiz.PlatformWriteResult{Code: errorcode.E_INTERNAL_ERROR, Message: "llm app unavailable", Success: false}
	}
	return llmbiz.CreateOllamaAgent(ctx, s.deps.Inference, in, cache)
}

// DeleteModel 删除推理服务上的模型。
func (s *AppService) DeleteModel(ctx context.Context, model string, cache llmbiz.ModelCacheClearer) llmbiz.PlatformWriteResult {
	if s == nil {
		return llmbiz.PlatformWriteResult{Code: errorcode.E_INTERNAL_ERROR, Message: "llm app unavailable", Success: false}
	}
	return llmbiz.DeleteOllamaModel(ctx, s.deps.Inference, model, cache)
}

// DownloadModel 下载推理服务模型。
func (s *AppService) DownloadModel(ctx context.Context, model string, cache llmbiz.ModelCacheClearer) llmbiz.PlatformWriteResult {
	if s == nil {
		return llmbiz.PlatformWriteResult{Code: errorcode.E_INTERNAL_ERROR, Message: "llm app unavailable", Success: false}
	}
	return llmbiz.DownloadOllamaModel(ctx, s.deps.Inference, model, cache)
}

// SetPlatformChatGateway 注入平台 chat 记忆/会话网关（进程启动时设置）。
func (s *AppService) SetPlatformChatGateway(gw llmbiz.PlatformChatGateway) {
	if s == nil {
		return
	}
	s.platformChatGateway = gw
}

func (s *AppService) platformChatDeps() llmbiz.PlatformChatDeps {
	deps := llmbiz.PlatformChatDeps{
		Inference:           s.deps.Inference,
		MemoryModel:         s.deps.MemoryModel,
		MemorySummaryPrompt: s.deps.MemorySummaryPrompt,
		MemoryExtractPrompt: s.deps.MemoryExtractPrompt,
		MemoryBudget:        llmbiz.DefaultMemoryBudget(),
		Gateway:             s.platformChatGateway,
		ChatComplete: func(ctx context.Context, model string, messages []llmbiz.ChatMessage, opts llmbiz.ChatOptions) (string, error) {
			return s.PostChatCompletion(ctx, model, messages, opts)
		},
	}
	return deps
}

// Chat 执行平台 chat（biz 直挂）。
func (s *AppService) Chat(ctx context.Context, in llmbiz.PlatformChatInput) (llmbiz.PlatformChatOutcome, error) {
	if s == nil {
		return llmbiz.PlatformChatOutcome{}, errors.New("llm app unavailable")
	}
	return llmbiz.ExecutePlatformChat(ctx, s.platformChatDeps(), in)
}
