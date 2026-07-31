package companiondata

import (
	"context"
	"errors"
	"time"

	companionbiz "backend/internal/biz/companion"
	"backend/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type store struct {
	db *gorm.DB
}

func NewStore(db *gorm.DB) companionbiz.Store {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

// ── Profile ──

func (s *store) GetProfileByUserID(ctx context.Context, userID uint) (*model.CompanionProfile, error) {
	var row model.CompanionProfile
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &row, nil
}

func (s *store) UpsertProfile(ctx context.Context, p *model.CompanionProfile) error {
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "user_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"name", "emoji", "avatar_url", "persona", "personality_traits_json",
				"greeting_style", "system_prompt_override",
				"agent_id", "life_entity_id", "updated_at",
			}),
		}).
		Create(p).Error
}

func (s *store) UpdateIntimacy(ctx context.Context, userID uint, intimacy float64, level int) error {
	return s.db.WithContext(ctx).
		Model(&model.CompanionProfile{}).
		Where("user_id = ?", userID).
		Updates(map[string]interface{}{
			"intimacy_score":     intimacy,
			"relationship_level": level,
			"updated_at":         time.Now(),
		}).Error
}

func (s *store) ListProfileUserIDs(ctx context.Context) ([]uint, error) {
	var userIDs []uint
	err := s.db.WithContext(ctx).
		Model(&model.CompanionProfile{}).
		Order("user_id ASC").
		Pluck("user_id", &userIDs).Error
	return userIDs, err
}

// ── Memory ──

func (s *store) CreateMemory(ctx context.Context, m *model.CompanionMemory) error {
	return s.db.WithContext(ctx).Create(m).Error
}

func (s *store) ListActiveMemories(ctx context.Context, userID uint, limit int) ([]model.CompanionMemory, error) {
	if limit <= 0 {
		limit = 10
	}
	var rows []model.CompanionMemory
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND (expires_at IS NULL OR expires_at > ? OR pinned = ?)", userID, time.Now(), true).
		Order("pinned DESC, importance DESC, created_at DESC").
		Limit(limit).
		Find(&rows).Error
	return rows, err
}

func (s *store) GetMemoryByID(ctx context.Context, userID, memoryID uint) (*model.CompanionMemory, error) {
	var row model.CompanionMemory
	err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", memoryID, userID).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &row, nil
}

func (s *store) DeleteMemory(ctx context.Context, userID, memoryID uint) error {
	result := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", memoryID, userID).
		Delete(&model.CompanionMemory{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (s *store) UpdateMemoryPinned(
	ctx context.Context,
	userID, memoryID uint,
	pinned bool,
	importance int,
	expiresAt *time.Time,
) error {
	result := s.db.WithContext(ctx).
		Model(&model.CompanionMemory{}).
		Where("id = ? AND user_id = ?", memoryID, userID).
		Updates(map[string]interface{}{
			"pinned":     pinned,
			"importance": importance,
			"expires_at": expiresAt,
		})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (s *store) UpdateMemoryContent(ctx context.Context, userID, memoryID uint, content string) error {
	result := s.db.WithContext(ctx).
		Model(&model.CompanionMemory{}).
		Where("id = ? AND user_id = ?", memoryID, userID).
		Update("content", content)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (s *store) CleanupExpiredMemories(ctx context.Context) (int64, error) {
	result := s.db.WithContext(ctx).
		Where("pinned = ? AND expires_at IS NOT NULL AND expires_at < ?", false, time.Now()).
		Delete(&model.CompanionMemory{})
	return result.RowsAffected, result.Error
}

// ── Chat Log ──

func (s *store) AppendChatLog(ctx context.Context, log *model.CompanionChatLog) error {
	return s.db.WithContext(ctx).Create(log).Error
}

func (s *store) ListRecentChatLogs(ctx context.Context, userID uint, limit int) ([]model.CompanionChatLog, error) {
	if limit <= 0 {
		limit = 20
	}
	var rows []model.CompanionChatLog
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("id DESC").
		Limit(limit).
		Find(&rows).Error
	if err != nil {
		return nil, err
	}
	// 反转为时间正序（与 game store 一致）
	for i, j := 0, len(rows)-1; i < j; i, j = i+1, j-1 {
		rows[i], rows[j] = rows[j], rows[i]
	}
	return rows, nil
}
