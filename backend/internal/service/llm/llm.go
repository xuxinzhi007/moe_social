package llmapp

import (
	"context"
	"net/http"

	llmv1 "backend/api/llm/v1"
	aibiz "backend/internal/biz/ai"
	llmbiz "backend/internal/biz/llm"
	aidata "backend/internal/data/ai"
	llmdata "backend/internal/data/llm"
	"backend/pkg/conf"
	"backend/pkg/llminference"
	kerrors "github.com/go-kratos/kratos/v2/errors"
	"gorm.io/gorm"
)

type Deps struct {
	// UserID is apicomm.UserIDUint, injected by wiring to avoid the apicomm/svc cycle.
	UserID          func(context.Context) (uint, error)
	Inference       llminference.Config
	ModelManagement conf.ModelManagement
	ModelStore      llmbiz.ManagedStore
}
type AppService struct {
	db     *gorm.DB
	deps   Deps
	models *llmbiz.ManagedModels
}

func New(db *gorm.DB, deps Deps) *AppService {
	if deps.ModelStore == nil && db != nil {
		deps.ModelStore = llmdata.NewStore(db)
	}
	deps.ModelManagement = conf.NormalizeModelManagement(deps.ModelManagement, deps.Inference.DefaultModel)
	return &AppService{db: db, deps: deps, models: llmbiz.NewManagedModels(deps.ModelStore, deps.Inference, deps.ModelManagement)}
}
func (s *AppService) actor(ctx context.Context, required bool) (uint, error) {
	if s.deps.UserID == nil {
		if required || ctx.Value("userId") != nil || ctx.Value("user_id") != nil {
			return 0, kerrors.Unauthorized("LLM_AUTH", "身份解析不可用")
		}
		return 0, nil
	}
	id, err := s.deps.UserID(ctx)
	if err != nil || id == 0 {
		if required || ctx.Value("userId") != nil || ctx.Value("user_id") != nil {
			return 0, kerrors.Unauthorized("LLM_AUTH", "请先登录")
		}
		return 0, nil
	}
	return id, nil
}
func (s *AppService) available() error {
	if s == nil || s.models == nil {
		return kerrors.ServiceUnavailable("LLM_UNAVAILABLE", "推理服务不可用")
	}
	return nil
}
func (s *AppService) GetAiUserConfig(ctx context.Context, in *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	return aibiz.GetAiUserConfig(ctx, aidata.NewStore(s.db), in)
}
func (s *AppService) UpsertAiUserConfig(ctx context.Context, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	return aibiz.UpsertAiUserConfig(ctx, aidata.NewStore(s.db), in)
}
func (s *AppService) Chat(ctx context.Context, in llmbiz.PlatformChatInput) (llmbiz.PlatformChatOutcome, error) {
	if err := s.available(); err != nil {
		return llmbiz.PlatformChatOutcome{}, err
	}
	id, err := s.actor(ctx, false)
	if err != nil {
		return llmbiz.PlatformChatOutcome{}, err
	}
	if in.Model == "" {
		in.Model = s.deps.Inference.DefaultModel
	}
	if err := s.models.Authorize(ctx, id, in.Model); err != nil {
		return llmbiz.PlatformChatOutcome{}, err
	}
	return llmbiz.ExecutePlatformChat(ctx, llmbiz.PlatformChatDeps{Inference: s.deps.Inference}, in)
}
func (s *AppService) ConfigAPIPayload() map[string]interface{} {
	return llmbiz.ConfigAPIPayload(s.ConfigSnapshot())
}
func (s *AppService) ConfigSnapshot() llmbiz.ConfigSnapshot {
	if s == nil {
		return llmbiz.ConfigSnapshot{}
	}
	return llmbiz.ConfigSnapshot{InferenceAPIStyle: string(s.deps.Inference.APIStyle), InferenceTimeoutSec: int(s.deps.Inference.Timeout.Seconds()), MemoryModel: s.deps.Inference.DefaultModel, MemoryBudget: llmbiz.DefaultMemoryBudget(), SupportsModelManagement: s.deps.ModelStore != nil && s.deps.Inference.Ready() && string(s.deps.Inference.APIStyle) == "ollama", ModelSyncTimeoutSeconds: s.deps.ModelManagement.ModelSyncTimeoutSeconds}
}
func (s *AppService) ListModels(ctx context.Context) ([]string, error) {
	if err := s.available(); err != nil {
		return nil, err
	}
	id, err := s.actor(ctx, false)
	if err != nil {
		return nil, err
	}
	return s.models.ListModels(ctx, id)
}
func (s *AppService) ForwardChatRaw(w http.ResponseWriter, r *http.Request) error {
	if err := s.available(); err != nil {
		return err
	}
	id, err := s.actor(r.Context(), false)
	if err != nil {
		return err
	}
	return s.models.ForwardChatRaw(w, r, id)
}
func (s *AppService) ForwardModelsRaw(w http.ResponseWriter, r *http.Request) error {
	if err := s.available(); err != nil {
		return err
	}
	id, err := s.actor(r.Context(), false)
	if err != nil {
		return err
	}
	return s.models.ForwardModelsRaw(r.Context(), w, id)
}
func (s *AppService) ForwardShowRaw(w http.ResponseWriter, r *http.Request) error {
	if err := s.available(); err != nil {
		return err
	}
	id, err := s.actor(r.Context(), false)
	if err != nil {
		return err
	}
	return s.models.ForwardShowRaw(w, r, id)
}
func (s *AppService) UpsertManagedModel(ctx context.Context, in llmbiz.CreateAgentInput) (llmbiz.ManagedModelView, error) {
	if err := s.available(); err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	id, err := s.actor(ctx, true)
	if err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	return s.models.Upsert(ctx, id, in)
}
func (s *AppService) ListManagedModels(ctx context.Context) ([]llmbiz.ManagedModelView, error) {
	if err := s.available(); err != nil {
		return nil, err
	}
	id, err := s.actor(ctx, true)
	if err != nil {
		return nil, err
	}
	return s.models.List(ctx, id)
}
func (s *AppService) GetManagedModel(ctx context.Context, agentID string) (llmbiz.ManagedModelView, error) {
	if err := s.available(); err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	id, err := s.actor(ctx, true)
	if err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	return s.models.Get(ctx, id, agentID)
}
func (s *AppService) ReconcileManagedModel(ctx context.Context, agentID string) (llmbiz.ManagedModelView, error) {
	if err := s.available(); err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	id, err := s.actor(ctx, true)
	if err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	return s.models.Reconcile(ctx, id, agentID)
}
func (s *AppService) DeleteManagedModel(ctx context.Context, agentID, requestID string) (llmbiz.ManagedModelView, error) {
	if err := s.available(); err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	id, err := s.actor(ctx, true)
	if err != nil {
		return llmbiz.ManagedModelView{}, err
	}
	return s.models.Delete(ctx, id, agentID, requestID)
}
