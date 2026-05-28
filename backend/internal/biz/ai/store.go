package aibiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// AiStore AI 资源与用户配置持久化（P4-D；默认由 internal/data/ai 实现）。
type AiStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) AiStore

	LoadOrCreateConfig(ctx context.Context, userID uint) (*model.AiUserConfig, error)
	SaveConfig(ctx context.Context, cfg *model.AiUserConfig) error
	FindAllConfigs(ctx context.Context) ([]model.AiUserConfig, error)
	GetUserDisplayName(ctx context.Context, userID uint) string
}
