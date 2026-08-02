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

func (s *store) UpdateProactiveSettings(
	ctx context.Context,
	userID uint,
	enabled bool,
	dailyLimit, quietStart, quietEnd, timezoneOffset int,
) error {
	var existing model.CompanionProfile
	if err := s.db.WithContext(ctx).
		Select("id").
		Where("user_id = ?", userID).
		First(&existing).Error; err != nil {
		return err
	}
	return s.db.WithContext(ctx).
		Model(&model.CompanionProfile{}).
		Where("user_id = ?", userID).
		Updates(map[string]interface{}{
			"proactive_enabled":         enabled,
			"proactive_daily_limit":     dailyLimit,
			"proactive_quiet_start":     quietStart,
			"proactive_quiet_end":       quietEnd,
			"proactive_timezone_offset": timezoneOffset,
			"updated_at":                time.Now(),
		}).Error
}

func (s *store) UpdateIntimacy(ctx context.Context, userID uint, intimacy float64, level int) error {
	var existing model.CompanionProfile
	if err := s.db.WithContext(ctx).
		Select("id").
		Where("user_id = ?", userID).
		First(&existing).Error; err != nil {
		return err
	}
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

func (s *store) ListProfileUserIDsByLifeEntityID(ctx context.Context, entityID uint) ([]uint, error) {
	if entityID == 0 {
		return nil, nil
	}
	var userIDs []uint
	err := s.db.WithContext(ctx).
		Model(&model.CompanionProfile{}).
		Where("life_entity_id = ?", entityID).
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

func (s *store) CorrectMemoryContent(
	ctx context.Context,
	userID, memoryID uint,
	content string,
	confirmedAt time.Time,
) error {
	result := s.db.WithContext(ctx).
		Model(&model.CompanionMemory{}).
		Where("id = ? AND user_id = ?", memoryID, userID).
		Updates(map[string]interface{}{
			"content":        content,
			"user_confirmed": true,
			"confirmed_at":   confirmedAt,
		})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// UpdateMemoryRecord replaces an unconfirmed extracted memory with newer evidence.
func (s *store) UpdateMemoryRecord(
	ctx context.Context,
	userID, memoryID uint,
	memoryType, memoryKey, content string,
	importance int,
	expiresAt *time.Time,
	confidence float64,
) error {
	result := s.db.WithContext(ctx).
		Model(&model.CompanionMemory{}).
		Where("id = ? AND user_id = ? AND user_confirmed = ?", memoryID, userID, false).
		Updates(map[string]interface{}{
			"memory_type": memoryType,
			"memory_key":  memoryKey,
			"content":     content,
			"importance":  importance,
			"expires_at":  expiresAt,
			"confidence":  confidence,
		})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// ConfirmMemory marks a memory as reviewed by its owner.
func (s *store) ConfirmMemory(ctx context.Context, userID, memoryID uint, confirmedAt time.Time) error {
	result := s.db.WithContext(ctx).
		Model(&model.CompanionMemory{}).
		Where("id = ? AND user_id = ?", memoryID, userID).
		Updates(map[string]interface{}{
			"user_confirmed": true,
			"confirmed_at":   confirmedAt,
		})
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

func (s *store) CreateMemoryConflict(ctx context.Context, conflict *model.CompanionMemoryConflict) error {
	return s.db.WithContext(ctx).Create(conflict).Error
}

func (s *store) ListMemoryConflicts(
	ctx context.Context,
	userID uint,
	limit int,
) ([]model.CompanionMemoryConflict, error) {
	if limit <= 0 {
		limit = 20
	}
	var rows []model.CompanionMemoryConflict
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND status = ?", userID, "pending").
		Order("created_at DESC, id DESC").
		Limit(limit).
		Find(&rows).Error
	return rows, err
}

func (s *store) GetMemoryConflict(
	ctx context.Context,
	userID, conflictID uint,
) (*model.CompanionMemoryConflict, error) {
	var row model.CompanionMemoryConflict
	err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", conflictID, userID).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &row, nil
}

func (s *store) ResolveMemoryConflict(
	ctx context.Context,
	userID, conflictID uint,
	status string,
	resolvedAt time.Time,
) error {
	result := s.db.WithContext(ctx).
		Model(&model.CompanionMemoryConflict{}).
		Where("id = ? AND user_id = ? AND status = ?", conflictID, userID, "pending").
		Updates(map[string]interface{}{
			"status":      status,
			"resolved_at": resolvedAt,
		})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
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

// CreateRelationshipEvent persists one meaningful relationship event.
func (s *store) CreateRelationshipEvent(ctx context.Context, event *model.CompanionRelationshipEvent) error {
	return s.db.WithContext(ctx).Create(event).Error
}

// ListRelationshipEvents returns the newest relationship events first.
func (s *store) ListRelationshipEvents(ctx context.Context, userID uint, limit int) ([]model.CompanionRelationshipEvent, error) {
	if limit <= 0 {
		limit = 20
	}
	var rows []model.CompanionRelationshipEvent
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC, id DESC").
		Limit(limit).
		Find(&rows).Error
	return rows, err
}

// CreateCompanionEvent persists one cross-domain companion event.
func (s *store) CreateCompanionEvent(ctx context.Context, event *model.CompanionEvent) error {
	return s.db.WithContext(ctx).
		Clauses(clause.OnConflict{DoNothing: true}).
		Create(event).Error
}

// ListCompanionEvents returns the newest unified events first.
func (s *store) ListCompanionEvents(ctx context.Context, userID uint, limit int) ([]model.CompanionEvent, error) {
	if limit <= 0 {
		limit = 50
	}
	var rows []model.CompanionEvent
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("occurred_at DESC, id DESC").
		Limit(limit).
		Find(&rows).Error
	return rows, err
}
