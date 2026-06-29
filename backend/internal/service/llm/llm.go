package llmapp

import (
	"context"
	"errors"
	"net/http"

	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	llmbiz "backend/internal/biz/llm"
	llmv1 "backend/api/llm/v1"
	"backend/pkg/llminference"

	"gorm.io/gorm"
)

type Deps struct {
	Inference llminference.Config
}

type AppService struct {
	db   *gorm.DB
	deps Deps
}

func New(db *gorm.DB, deps Deps) *AppService {
	return &AppService{db: db, deps: deps}
}

func (s *AppService) GetAiUserConfig(ctx context.Context, in *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	return aibiz.GetAiUserConfig(ctx, aidata.NewStore(s.db), in)
}

func (s *AppService) UpsertAiUserConfig(ctx context.Context, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	return aibiz.UpsertAiUserConfig(ctx, aidata.NewStore(s.db), in)
}

func (s *AppService) Chat(ctx context.Context, in llmbiz.PlatformChatInput) (llmbiz.PlatformChatOutcome, error) {
	if s == nil {
		return llmbiz.PlatformChatOutcome{}, nil
	}
	deps := llmbiz.PlatformChatDeps{
		Inference: s.deps.Inference,
	}
	return llmbiz.ExecutePlatformChat(ctx, deps, in)
}

func (s *AppService) ConfigAPIPayload() map[string]interface{} {
	if s == nil {
		return llmbiz.ConfigAPIPayload(llmbiz.ConfigSnapshot{})
	}
	return llmbiz.ConfigAPIPayload(s.ConfigSnapshot())
}

func (s *AppService) ConfigSnapshot() llmbiz.ConfigSnapshot {
	if s == nil {
		return llmbiz.ConfigSnapshot{}
	}
	return llmbiz.ConfigSnapshot{
		InferenceBaseURL:    s.deps.Inference.BaseURL,
		InferenceAPIStyle:   string(s.deps.Inference.APIStyle),
		InferenceTimeoutSec: int(s.deps.Inference.Timeout.Seconds()),
		MemoryBudget:        llmbiz.DefaultMemoryBudget(),
	}
}

func (s *AppService) ForwardChatRaw(w http.ResponseWriter, r *http.Request) error {
	if s == nil {
		return errors.New("llm app unavailable")
	}
	return llmbiz.ForwardChatRaw(w, r, s.deps.Inference)
}

func (s *AppService) ForwardModelsRaw(w http.ResponseWriter, r *http.Request) error {
	if s == nil {
		return errors.New("llm app unavailable")
	}
	return llmbiz.ForwardModelsRaw(w, r, s.deps.Inference)
}

func (s *AppService) ForwardShowRaw(w http.ResponseWriter, r *http.Request) error {
	if s == nil {
		return errors.New("llm app unavailable")
	}
	return llmbiz.ForwardShowRaw(w, r, s.deps.Inference)
}

func (s *AppService) CreateAgent(ctx context.Context, in llmbiz.CreateAgentInput, cache llmbiz.ModelCacheClearer) llmbiz.PlatformWriteResult {
	if s == nil {
		return llmbiz.PlatformWriteResult{Code: 500, Message: "llm app unavailable", Success: false}
	}
	return llmbiz.CreateOllamaAgent(ctx, s.deps.Inference, in, cache)
}

func (s *AppService) DeleteModel(ctx context.Context, model string, cache llmbiz.ModelCacheClearer) llmbiz.PlatformWriteResult {
	if s == nil {
		return llmbiz.PlatformWriteResult{Code: 500, Message: "llm app unavailable", Success: false}
	}
	return llmbiz.DeleteOllamaModel(ctx, s.deps.Inference, model, cache)
}

func (s *AppService) DownloadModel(ctx context.Context, model string, cache llmbiz.ModelCacheClearer) llmbiz.PlatformWriteResult {
	if s == nil {
		return llmbiz.PlatformWriteResult{Code: 500, Message: "llm app unavailable", Success: false}
	}
	return llmbiz.DownloadOllamaModel(ctx, s.deps.Inference, model, cache)
}
