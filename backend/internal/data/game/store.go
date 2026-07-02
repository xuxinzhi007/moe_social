package gamedata

import (
	"context"
	"errors"

	gamebiz "backend/internal/biz/game"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

func NewStore(db *gorm.DB) gamebiz.Store {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) gamebiz.Store {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) CountSeedScenes(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.GameScene{}).Where("is_seed = ?", true).Count(&n).Error
	return n, err
}

func (s *store) CreateScene(ctx context.Context, row *model.GameScene) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) CreateNpc(ctx context.Context, row *model.GameNpc) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) FindSeedSceneByName(ctx context.Context, name string) (model.GameScene, bool, error) {
	var row model.GameScene
	err := s.db.WithContext(ctx).Where("is_seed = ? AND name = ?", true, name).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GameScene{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) ListNpcsByScene(ctx context.Context, sceneID uint) ([]model.GameNpc, error) {
	var rows []model.GameNpc
	err := s.db.WithContext(ctx).Where("scene_id = ?", sceneID).Order("id ASC").Find(&rows).Error
	return rows, err
}

func (s *store) FindActiveSession(ctx context.Context, userID uint) (model.GameSession, bool, error) {
	var row model.GameSession
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND is_active = ?", userID, true).
		Order("updated_at DESC").
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GameSession{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) GetSession(ctx context.Context, userID, sessionID uint) (model.GameSession, error) {
	var row model.GameSession
	err := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", sessionID, userID).First(&row).Error
	return row, err
}

func (s *store) DeactivateSessions(ctx context.Context, userID uint) error {
	return s.db.WithContext(ctx).Model(&model.GameSession{}).
		Where("user_id = ? AND is_active = ?", userID, true).
		Update("is_active", false).Error
}

func (s *store) CreateSession(ctx context.Context, row *model.GameSession) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) UpdateSession(ctx context.Context, sessionID uint, updates map[string]interface{}) error {
	return s.db.WithContext(ctx).Model(&model.GameSession{}).Where("id = ?", sessionID).Updates(updates).Error
}

func (s *store) GetScene(ctx context.Context, sceneID uint) (model.GameScene, error) {
	var row model.GameScene
	err := s.db.WithContext(ctx).Where("id = ?", sceneID).First(&row).Error
	return row, err
}

func (s *store) ListNpcMemories(ctx context.Context, playerID, npcID uint, limit int) ([]model.GameNpcMemory, error) {
	if limit <= 0 {
		limit = 8
	}
	var rows []model.GameNpcMemory
	err := s.db.WithContext(ctx).
		Where("player_id = ? AND npc_id = ?", playerID, npcID).
		Order("importance DESC, id DESC").
		Limit(limit).
		Find(&rows).Error
	return rows, err
}

func (s *store) CreateNpcMemory(ctx context.Context, row *model.GameNpcMemory) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) FindSceneByName(ctx context.Context, name string) (model.GameScene, bool, error) {
	var row model.GameScene
	err := s.db.WithContext(ctx).Where("name = ?", name).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GameScene{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) ListTurnLogs(ctx context.Context, sessionID uint, limit int) ([]model.GameTurnLog, error) {
	if limit <= 0 {
		limit = 30
	}
	var rows []model.GameTurnLog
	err := s.db.WithContext(ctx).
		Where("session_id = ?", sessionID).
		Order("id ASC").
		Limit(limit).
		Find(&rows).Error
	return rows, err
}

func (s *store) ListRecentTurnLogs(ctx context.Context, sessionID uint, limit int) ([]model.GameTurnLog, error) {
	if limit <= 0 {
		limit = 10
	}
	var rows []model.GameTurnLog
	err := s.db.WithContext(ctx).
		Where("session_id = ?", sessionID).
		Order("id DESC").
		Limit(limit).
		Find(&rows).Error
	if err != nil {
		return nil, err
	}
	for i, j := 0, len(rows)-1; i < j; i, j = i+1, j-1 {
		rows[i], rows[j] = rows[j], rows[i]
	}
	return rows, nil
}

func (s *store) CreateTurnLog(ctx context.Context, row *model.GameTurnLog) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) CreateWorldItem(ctx context.Context, row *model.GameWorldItem) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) ListInventoryItems(ctx context.Context, sessionID uint) ([]model.GameWorldItem, error) {
	var rows []model.GameWorldItem
	err := s.db.WithContext(ctx).
		Where("session_id = ? AND in_inventory = ?", sessionID, true).
		Order("id ASC").
		Find(&rows).Error
	return rows, err
}

func (s *store) ListSceneItems(ctx context.Context, sessionID, sceneID uint) ([]model.GameWorldItem, error) {
	var rows []model.GameWorldItem
	err := s.db.WithContext(ctx).
		Where("session_id = ? AND scene_id = ? AND in_inventory = ?", sessionID, sceneID, false).
		Order("id ASC").
		Find(&rows).Error
	return rows, err
}

func (s *store) FindWorldItemByName(ctx context.Context, sessionID, sceneID uint, name string, inInventory bool) (model.GameWorldItem, bool, error) {
	var row model.GameWorldItem
	q := s.db.WithContext(ctx).Where("session_id = ? AND name = ? AND in_inventory = ?", sessionID, name, inInventory)
	if !inInventory {
		q = q.Where("scene_id = ?", sceneID)
	}
	err := q.First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GameWorldItem{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) MoveItemToInventory(ctx context.Context, itemID uint) error {
	return s.db.WithContext(ctx).Model(&model.GameWorldItem{}).Where("id = ?", itemID).
		Updates(map[string]interface{}{"in_inventory": true, "scene_id": 0}).Error
}
