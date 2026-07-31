package lifebiz

import (
	"context"

	"backend/model"
)

// Store 定义 LifeEngine 的持久化操作接口。
type Store interface {
	// Entity CRUD
	ListEntities(ctx context.Context, worldID string) ([]model.LifeEntity, error)
	// GetEntityByID 按主键取实体（含已软删除），不存在返回 nil。
	GetEntityByID(ctx context.Context, entityID uint) (*model.LifeEntity, error)
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
	ListRecentEventLogsByEntity(ctx context.Context, worldID string, entityID uint, limit int) ([]model.LifeEventLog, error)
	CleanupOldEventLogs(ctx context.Context) (int64, error)

	// 社交关系
	UpsertRelationship(ctx context.Context, rel *model.LifeRelationship) error
	BatchUpsertRelationships(ctx context.Context, rels []*model.LifeRelationship) error
	ListRelationshipsByWorld(ctx context.Context, worldID string) ([]*model.LifeRelationship, error)
	ListRelationshipsByEntity(ctx context.Context, entityID uint) ([]*model.LifeRelationship, error)
	DeleteRelationship(ctx context.Context, id uint) error
	BatchDeleteRelationships(ctx context.Context, ids []uint) error

	// 道具与背包
	ListItems(ctx context.Context) ([]*model.LifeItem, error)
	GetItem(ctx context.Context, id uint) (*model.LifeItem, error)
	SeedItems(ctx context.Context, items []*model.LifeItem) error
	GetInventory(ctx context.Context, userID string) ([]*model.LifeInventory, error)
	DecrementInventory(ctx context.Context, userID string, itemID uint) error
	GrantItem(ctx context.Context, userID string, itemID uint, qty int) error

	// 背包每日签到
	HasDailyClaim(ctx context.Context, userID, claimDate string) (bool, error)
	// MarkDailyClaim 写入签到记录；同日重复返回 created=false。
	MarkDailyClaim(ctx context.Context, userID, claimDate string, itemCount int) (created bool, err error)
	UpdateDailyClaimCount(ctx context.Context, userID, claimDate string, itemCount int) error
}
