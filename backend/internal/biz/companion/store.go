package companionbiz

import (
	"context"

	"backend/model"
)

// Store 定义 Companion 模块的持久化操作接口（由 data 层实现）。
type Store interface {
	// Profile
	GetProfileByUserID(ctx context.Context, userID uint) (*model.CompanionProfile, error)
	UpsertProfile(ctx context.Context, p *model.CompanionProfile) error

	// Memory
	CreateMemory(ctx context.Context, m *model.CompanionMemory) error
	ListActiveMemories(ctx context.Context, userID uint, limit int) ([]model.CompanionMemory, error)
	CleanupExpiredMemories(ctx context.Context) (int64, error)

	// Chat Log
	AppendChatLog(ctx context.Context, log *model.CompanionChatLog) error
	ListRecentChatLogs(ctx context.Context, userID uint, limit int) ([]model.CompanionChatLog, error)
}
