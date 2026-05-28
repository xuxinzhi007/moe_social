package moebiz

import (
	"context"

	"backend/model"
	"backend/pkg/moe/toolaudit"

	"gorm.io/gorm"
)

// MoeStore Moe 域持久化（P4-D；默认由 internal/data/moe 实现）。
type MoeStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) MoeStore

	ListRuntimes(ctx context.Context) ([]model.MoeAgentRuntime, error)
	UpsertRuntime(ctx context.Context, rt *model.MoeAgentRuntime) error
	GetRuntimeByAgentKey(ctx context.Context, agentKey string) (model.MoeAgentRuntime, error)
	MarkUserAsBot(ctx context.Context, userID uint, agentKey string) error
	UpdateRuntimePolicy(ctx context.Context, agentKey, forbiddenTags, preferredTags string) error

	FindFlowConfigByAgentKey(ctx context.Context, agentKey string) (model.MoeAgentFlowConfig, bool, error)
	CreateFlowConfig(ctx context.Context, row *model.MoeAgentFlowConfig) error
	SaveFlowConfig(ctx context.Context, row *model.MoeAgentFlowConfig) error
	DeleteFlowConfigByAgentKey(ctx context.Context, agentKey string) error

	QueryToolStats(ctx context.Context, f toolaudit.StatsFilter) (toolaudit.StatsResult, error)
	ListToolCalls(ctx context.Context, f toolaudit.ListFilter) ([]model.MoeToolCall, int64, error)
}

func dbFromStore(ctx context.Context, st MoeStore) *gorm.DB {
	if st == nil {
		return nil
	}
	if ctx != nil {
		return st.WithContext(ctx).Raw()
	}
	return st.Raw()
}
