package moedata

import (
	"context"
	"errors"

	moebiz "backend/internal/biz/moe"
	"backend/model"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.MoeStore（P4-D）。
func NewStore(db *gorm.DB) moebiz.MoeStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) moebiz.MoeStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) ListRuntimes(ctx context.Context) ([]model.MoeAgentRuntime, error) {
	return runtime.ListRuntimes(s.db.WithContext(ctx))
}

func (s *store) UpsertRuntime(ctx context.Context, rt *model.MoeAgentRuntime) error {
	return runtime.UpsertRuntime(s.db.WithContext(ctx), rt)
}

func (s *store) GetRuntimeByAgentKey(ctx context.Context, agentKey string) (model.MoeAgentRuntime, error) {
	var row model.MoeAgentRuntime
	err := s.db.WithContext(ctx).Where("agent_key = ?", agentKey).First(&row).Error
	return row, err
}

func (s *store) MarkUserAsBot(ctx context.Context, userID uint, agentKey string) error {
	return s.db.WithContext(ctx).Model(&model.User{}).Where("id = ?", userID).Updates(map[string]any{
		"is_bot":        true,
		"bot_agent_key": agentKey,
	}).Error
}

func (s *store) UpdateRuntimePolicy(ctx context.Context, agentKey, forbiddenTags, preferredTags string) error {
	return s.db.WithContext(ctx).Model(&model.MoeAgentRuntime{}).Where("agent_key = ?", agentKey).Updates(map[string]any{
		"forbidden_tags": forbiddenTags,
		"preferred_tags": preferredTags,
	}).Error
}

func (s *store) FindFlowConfigByAgentKey(ctx context.Context, agentKey string) (model.MoeAgentFlowConfig, bool, error) {
	var row model.MoeAgentFlowConfig
	err := s.db.WithContext(ctx).Where("agent_key = ?", agentKey).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.MoeAgentFlowConfig{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) CreateFlowConfig(ctx context.Context, row *model.MoeAgentFlowConfig) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) SaveFlowConfig(ctx context.Context, row *model.MoeAgentFlowConfig) error {
	return s.db.WithContext(ctx).Save(row).Error
}

func (s *store) DeleteFlowConfigByAgentKey(ctx context.Context, agentKey string) error {
	return s.db.WithContext(ctx).Where("agent_key = ?", agentKey).Delete(&model.MoeAgentFlowConfig{}).Error
}

func (s *store) QueryToolStats(ctx context.Context, f toolaudit.StatsFilter) (toolaudit.StatsResult, error) {
	return toolaudit.QueryStats(s.db.WithContext(ctx), f)
}

func (s *store) ListToolCalls(ctx context.Context, f toolaudit.ListFilter) ([]model.MoeToolCall, int64, error) {
	return toolaudit.ListCalls(s.db.WithContext(ctx), f)
}
