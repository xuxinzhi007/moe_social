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
				"age", "growth_stage", "experience", "active_effects_json",
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
				"age", "growth_stage", "experience", "active_effects_json",
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

func (s *gormStore) ListRecentEventLogsByEntity(
	ctx context.Context,
	worldID string,
	entityID uint,
	limit int,
) ([]model.LifeEventLog, error) {
	if limit <= 0 {
		limit = 5
	}
	var logs []model.LifeEventLog
	err := s.db.WithContext(ctx).
		Where("world_id = ? AND entity_id = ?", worldID, entityID).
		Order("created_at DESC").
		Limit(limit).
		Find(&logs).Error
	return logs, err
}

func (s *gormStore) CleanupOldEventLogs(ctx context.Context) (int64, error) {
	now := time.Now()
	// 普通事件 7 天 TTL
	r1 := s.db.WithContext(ctx).
		Where("importance = ? AND created_at < ?", 0, now.Add(-7*24*time.Hour)).
		Delete(&model.LifeEventLog{})
	if r1.Error != nil {
		return 0, r1.Error
	}
	// 重要事件 30 天 TTL
	r2 := s.db.WithContext(ctx).
		Where("importance = ? AND created_at < ?", 1, now.Add(-30*24*time.Hour)).
		Delete(&model.LifeEventLog{})
	return r1.RowsAffected + r2.RowsAffected, r2.Error
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

// --- 社交关系 ---

func (s *gormStore) UpsertRelationship(ctx context.Context, rel *model.LifeRelationship) error {
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "world_id"}, {Name: "entity_id"}, {Name: "target_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"world_id", "relation_type", "affinity", "last_interaction_at", "updated_at",
			}),
		}).
		Create(rel).Error
}

func (s *gormStore) BatchUpsertRelationships(ctx context.Context, rels []*model.LifeRelationship) error {
	if len(rels) == 0 {
		return nil
	}
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "world_id"}, {Name: "entity_id"}, {Name: "target_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"world_id", "relation_type", "affinity", "last_interaction_at", "updated_at",
			}),
		}).
		Create(rels).Error
}

func (s *gormStore) ListRelationshipsByWorld(ctx context.Context, worldID string) ([]*model.LifeRelationship, error) {
	var rels []*model.LifeRelationship
	err := s.db.WithContext(ctx).Where("world_id = ?", worldID).Find(&rels).Error
	return rels, err
}

func (s *gormStore) ListRelationshipsByEntity(ctx context.Context, entityID uint) ([]*model.LifeRelationship, error) {
	var rels []*model.LifeRelationship
	err := s.db.WithContext(ctx).
		Where("entity_id = ? OR target_id = ?", entityID, entityID).
		Find(&rels).Error
	return rels, err
}

func (s *gormStore) DeleteRelationship(ctx context.Context, id uint) error {
	return s.db.WithContext(ctx).Delete(&model.LifeRelationship{}, id).Error
}

func (s *gormStore) BatchDeleteRelationships(ctx context.Context, ids []uint) error {
	if len(ids) == 0 {
		return nil
	}
	return s.db.WithContext(ctx).Where("id IN ?", ids).Delete(&model.LifeRelationship{}).Error
}

// --- 道具与背包 ---

func (s *gormStore) ListItems(ctx context.Context) ([]*model.LifeItem, error) {
	var items []*model.LifeItem
	err := s.db.WithContext(ctx).Find(&items).Error
	return items, err
}

func (s *gormStore) GetItem(ctx context.Context, id uint) (*model.LifeItem, error) {
	var item model.LifeItem
	err := s.db.WithContext(ctx).First(&item, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (s *gormStore) SeedItems(ctx context.Context, items []*model.LifeItem) error {
	if len(items) == 0 {
		return nil
	}
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{DoNothing: true}).
		Create(items).Error
}

func (s *gormStore) GetInventory(ctx context.Context, userID string) ([]*model.LifeInventory, error) {
	var inv []*model.LifeInventory
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).Find(&inv).Error
	return inv, err
}

func (s *gormStore) DecrementInventory(ctx context.Context, userID string, itemID uint) error {
	result := s.db.WithContext(ctx).
		Model(&model.LifeInventory{}).
		Where("user_id = ? AND item_id = ? AND quantity > 0", userID, itemID).
		Updates(map[string]interface{}{
			"quantity":   gorm.Expr("quantity - 1"),
			"updated_at": time.Now(),
		})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("inventory item not found or quantity is zero")
	}
	return nil
}

func (s *gormStore) GrantItem(ctx context.Context, userID string, itemID uint, qty int) error {
	inv := &model.LifeInventory{
		UserID:   userID,
		ItemID:   itemID,
		Quantity: qty,
	}
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "user_id"}, {Name: "item_id"}},
			DoUpdates: clause.Assignments(map[string]interface{}{
				"quantity":   gorm.Expr("quantity + ?", qty),
				"updated_at": time.Now(),
			}),
		}).
		Create(inv).Error
}
