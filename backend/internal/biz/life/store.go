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
	// SoftDeleteEntity 软删除实体（设置 is_alive=false）
	SoftDeleteEntity(ctx context.Context, entityID uint) error

	// World CRUD
	GetWorld(ctx context.Context, name string) (*model.LifeWorld, error)
	UpsertWorld(ctx context.Context, world *model.LifeWorld) error
	// UpdateWorldGridData 更新世界的生态网格序列化数据
	UpdateWorldGridData(ctx context.Context, worldName string, gridData string) error

	// Event Log
	CreateEventLog(ctx context.Context, log *model.LifeEventLog) error
	BatchCreateEventLogs(ctx context.Context, logs []*model.LifeEventLog) error
	ListRecentEventLogs(ctx context.Context, worldID string, limit int) ([]model.LifeEventLog, error)
	CleanupOldEventLogs(ctx context.Context, before time.Time) (int64, error)
}
