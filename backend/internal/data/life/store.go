package lifedata

import (
	"context"
	"errors"
	"time"

	lifebiz "backend/internal/biz/life"
	"backend/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type gormStore struct {
	db *gorm.DB
}

// NewStore 创建 LifeEngine 的 GORM 持久化实现。
func NewStore(db *gorm.DB) lifebiz.Store {
	if db == nil {
		return nil
	}
	return &gormStore{db: db}
}

// --- Entity CRUD ---

func (s *gormStore) ListEntities(ctx context.Context, worldID string) ([]model.LifeEntity, error) {
	var entities []model.LifeEntity
	err := s.db.WithContext(ctx).Where("world_id = ? AND is_alive = ?", worldID, true).Find(&entities).Error
	return entities, err
}

func (s *gormStore) UpsertEntity(ctx context.Context, entity *model.LifeEntity) error {
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"world_id", "name", "emoji",
				"hunger", "energy", "mood",
				"current_action", "position_x", "position_y",
				"target_entity_id", "is_alive", "last_action_at", "updated_at",
			}),
		}).
		Create(entity).Error
}

func (s *gormStore) BatchUpsertEntities(ctx context.Context, entities []*model.LifeEntity) error {
	if len(entities) == 0 {
		return nil
	}
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"world_id", "name", "emoji",
				"hunger", "energy", "mood",
				"current_action", "position_x", "position_y",
				"target_entity_id", "is_alive", "last_action_at", "updated_at",
			}),
		}).
		Create(entities).Error
}

// --- World CRUD ---

func (s *gormStore) GetWorld(ctx context.Context, name string) (*model.LifeWorld, error) {
	var world model.LifeWorld
	err := s.db.WithContext(ctx).Where("name = ?", name).First(&world).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &world, nil
}

func (s *gormStore) UpsertWorld(ctx context.Context, world *model.LifeWorld) error {
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "name"}},
			DoUpdates: clause.AssignmentColumns([]string{"tick_count", "is_running", "grid_data", "updated_at"}),
		}).
		Create(world).Error
}

// --- Event Log ---

func (s *gormStore) CreateEventLog(ctx context.Context, log *model.LifeEventLog) error {
	return s.db.WithContext(ctx).Create(log).Error
}

func (s *gormStore) BatchCreateEventLogs(ctx context.Context, logs []*model.LifeEventLog) error {
	if len(logs) == 0 {
		return nil
	}
	return s.db.WithContext(ctx).CreateInBatches(logs, 100).Error
}

func (s *gormStore) ListRecentEventLogs(ctx context.Context, worldID string, limit int) ([]model.LifeEventLog, error) {
	if limit <= 0 {
		limit = 50
	}
	var logs []model.LifeEventLog
	err := s.db.WithContext(ctx).
		Where("world_id = ?", worldID).
		Order("created_at DESC").
		Limit(limit).
		Find(&logs).Error
	return logs, err
}

func (s *gormStore) CleanupOldEventLogs(ctx context.Context, before time.Time) (int64, error) {
	result := s.db.WithContext(ctx).
		Where("created_at < ?", before).
		Delete(&model.LifeEventLog{})
	return result.RowsAffected, result.Error
}

// SoftDeleteEntity 软删除实体，设置 is_alive=false
func (s *gormStore) SoftDeleteEntity(ctx context.Context, entityID uint) error {
	return s.db.WithContext(ctx).
		Model(&model.LifeEntity{}).
		Where("id = ?", entityID).
		Update("is_alive", false).Error
}

// UpdateWorldGridData 更新世界的生态网格序列化数据
func (s *gormStore) UpdateWorldGridData(ctx context.Context, worldName string, gridData string) error {
	return s.db.WithContext(ctx).
		Model(&model.LifeWorld{}).
		Where("name = ?", worldName).
		Updates(map[string]interface{}{
			"grid_data":  gridData,
			"updated_at": time.Now(),
		}).Error
}
