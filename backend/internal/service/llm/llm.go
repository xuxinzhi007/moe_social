package llmapp

import (
	"context"
	"errors"
	"net/http"

	llmv1 "backend/api/llm/v1"
	aibiz "backend/internal/biz/ai"
	llmbiz "backend/internal/biz/llm"
	aidata "backend/internal/data/ai"
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
		MemoryModel:         s.deps.Inference.DefaultModel,
		MemoryBudget:        llmbiz.DefaultMemoryBudget(),
	}
}

func (s *AppService) ListModels(ctx context.Context) ([]string, error) {
	if s == nil {
		return nil, errors.New("llm app unavailable")
	}
	return llminference.ListModels(ctx, s.deps.Inference)
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
