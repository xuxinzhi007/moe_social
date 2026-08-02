package companionbiz

import (
	"context"
	"time"

	"backend/model"
)

// Store 定义 Companion 模块的持久化操作接口（由 data 层实现）。
type Store interface {
	// Profile
	GetProfileByUserID(ctx context.Context, userID uint) (*model.CompanionProfile, error)
	UpsertProfile(ctx context.Context, p *model.CompanionProfile) error
	UpdateProactiveSettings(ctx context.Context, userID uint, enabled bool, dailyLimit, quietStart, quietEnd, timezoneOffset int) error
	// UpdateIntimacy 只更新亲密相关字段，避免 Upsert 冲掉其它列。
	UpdateIntimacy(ctx context.Context, userID uint, intimacy float64, level int) error
	ListProfileUserIDs(ctx context.Context) ([]uint, error)
	ListProfileUserIDsByLifeEntityID(ctx context.Context, entityID uint) ([]uint, error)

	// Memory
	CreateMemory(ctx context.Context, m *model.CompanionMemory) error
	ListActiveMemories(ctx context.Context, userID uint, limit int) ([]model.CompanionMemory, error)
	GetMemoryByID(ctx context.Context, userID, memoryID uint) (*model.CompanionMemory, error)
	DeleteMemory(ctx context.Context, userID, memoryID uint) error
	UpdateMemoryPinned(ctx context.Context, userID, memoryID uint, pinned bool, importance int, expiresAt *time.Time) error
	CorrectMemoryContent(ctx context.Context, userID, memoryID uint, content string, confirmedAt time.Time) error
	UpdateMemoryRecord(ctx context.Context, userID, memoryID uint, memoryType, memoryKey, content string, importance int, expiresAt *time.Time, confidence float64) error
	ConfirmMemory(ctx context.Context, userID, memoryID uint, confirmedAt time.Time) error
	CleanupExpiredMemories(ctx context.Context) (int64, error)

	// Memory conflicts
	CreateMemoryConflict(ctx context.Context, conflict *model.CompanionMemoryConflict) error
	ListMemoryConflicts(ctx context.Context, userID uint, limit int) ([]model.CompanionMemoryConflict, error)
	GetMemoryConflict(ctx context.Context, userID, conflictID uint) (*model.CompanionMemoryConflict, error)
	ResolveMemoryConflict(ctx context.Context, userID, conflictID uint, status string, resolvedAt time.Time) error

	// Chat Log
	AppendChatLog(ctx context.Context, log *model.CompanionChatLog) error
	ListRecentChatLogs(ctx context.Context, userID uint, limit int) ([]model.CompanionChatLog, error)

	// Relationship Events
	CreateRelationshipEvent(ctx context.Context, event *model.CompanionRelationshipEvent) error
	ListRelationshipEvents(ctx context.Context, userID uint, limit int) ([]model.CompanionRelationshipEvent, error)

	// Unified event timeline
	CreateCompanionEvent(ctx context.Context, event *model.CompanionEvent) error
	ListCompanionEvents(ctx context.Context, userID uint, limit int) ([]model.CompanionEvent, error)
}

// LifeStore defines the Life data needed by the Companion domain.
type LifeStore interface {
	ListEntities(ctx context.Context, worldID string) ([]model.LifeEntity, error)
	// GetEntityByID 含已软删除；不存在返回 nil。
	GetEntityByID(ctx context.Context, entityID uint) (*model.LifeEntity, error)
	ListRecentEventLogsByEntity(ctx context.Context, worldID string, entityID uint, limit int) ([]model.LifeEventLog, error)
}

// World bind status values（写入 Profile / State，供前端展示）。
const (
	WorldBindUnbound = "unbound"
	WorldBindOK      = "bound_ok"
	WorldBindMissing = "bound_missing"
)
