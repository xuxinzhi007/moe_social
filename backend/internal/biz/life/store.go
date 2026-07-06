package lifebiz

import (
	"context"
	"time"

	"backend/model"
)

// Store 定义 LifeEngine 的持久化操作接口。
type Store interface {
	// Entity CRUD
	ListEntities(ctx context.Context, worldID string) ([]model.LifeEntity, error)
	UpsertEntity(ctx context.Context, entity *model.LifeEntity) error
	BatchUpsertEntities(ctx context.Context, entities []*model.LifeEntity) error

	// World CRUD
	GetWorld(ctx context.Context, name string) (*model.LifeWorld, error)
	UpsertWorld(ctx context.Context, world *model.LifeWorld) error

	// Event Log
	CreateEventLog(ctx context.Context, log *model.LifeEventLog) error
	BatchCreateEventLogs(ctx context.Context, logs []*model.LifeEventLog) error
	ListRecentEventLogs(ctx context.Context, worldID string, limit int) ([]model.LifeEventLog, error)
	CleanupOldEventLogs(ctx context.Context, before time.Time) (int64, error)
}
