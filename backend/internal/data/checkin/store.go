package checkindata

import (
	"context"
	"errors"
	"time"

	checkinbiz "backend/internal/biz/checkin"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.CheckInStore（P4-D2）。
func NewStore(db *gorm.DB) checkinbiz.CheckInStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) checkinbiz.CheckInStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) GetUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("id = ?", userID).First(&user).Error
	return user, err
}

func (s *store) UserExists(ctx context.Context, userID uint) error {
	return s.db.WithContext(ctx).Where("id = ?", userID).First(&model.User{}).Error
}

func (s *store) FindTodayCheckIn(ctx context.Context, userID uint, dayStart, dayEnd time.Time) (model.UserCheckIn, bool, error) {
	var row model.UserCheckIn
	err := s.db.WithContext(ctx).Where("user_id = ? AND check_in_date >= ? AND check_in_date < ?",
		userID, dayStart, dayEnd).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserCheckIn{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) FindLastCheckIn(ctx context.Context, userID uint) (model.UserCheckIn, bool, error) {
	var row model.UserCheckIn
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("check_in_date DESC").First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserCheckIn{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) FindCheckInReward(ctx context.Context, consecutiveDays int) (model.CheckInReward, bool, error) {
	var row model.CheckInReward
	err := s.db.WithContext(ctx).Where("consecutive_days <= ?", consecutiveDays).
		Order("consecutive_days DESC").First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.CheckInReward{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) CreateCheckIn(ctx context.Context, record *model.UserCheckIn) error {
	return s.db.WithContext(ctx).Create(record).Error
}

func (s *store) ListCheckIns(ctx context.Context, userID uint, page, pageSize int32) ([]model.UserCheckIn, int64, error) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}
	var total int64
	if err := s.db.WithContext(ctx).Model(&model.UserCheckIn{}).
		Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.UserCheckIn
	offset := int((page - 1) * pageSize)
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("check_in_date DESC").Limit(int(pageSize)).Offset(offset).Find(&rows).Error
	return rows, total, err
}

func (s *store) CountExpLogs(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.ExpLog{}).Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *store) ListExpLogs(ctx context.Context, userID uint, page, pageSize int32) ([]model.ExpLog, error) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}
	var rows []model.ExpLog
	offset := int((page - 1) * pageSize)
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC").Limit(int(pageSize)).Offset(offset).Find(&rows).Error
	return rows, err
}

func (s *store) GetUserLevel(ctx context.Context, userID uint) (model.UserLevel, bool, error) {
	var row model.UserLevel
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserLevel{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) CreateUserLevel(ctx context.Context, row *model.UserLevel) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) GetLevelConfig(ctx context.Context, level int) (model.LevelConfig, bool, error) {
	var row model.LevelConfig
	err := s.db.WithContext(ctx).Where("level = ?", level).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.LevelConfig{}, false, nil
	}
	return row, err == nil, err
}

func (s *store) Begin(ctx context.Context) (checkinbiz.CheckInTx, error) {
	tx := s.db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}
	return &txWrapper{tx: tx}, nil
}

type txWrapper struct {
	tx *gorm.DB
}

func (t *txWrapper) GetUser(userID uint) (model.User, error) {
	var user model.User
	err := t.tx.Where("id = ?", userID).First(&user).Error
	return user, err
}

func (t *txWrapper) FindTodayCheckIn(userID uint, dayStart, dayEnd time.Time) (model.UserCheckIn, bool, error) {
	var row model.UserCheckIn
	err := t.tx.Where("user_id = ? AND check_in_date >= ? AND check_in_date < ?",
		userID, dayStart, dayEnd).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserCheckIn{}, false, nil
	}
	return row, err == nil, err
}

func (t *txWrapper) FindLastCheckIn(userID uint) (model.UserCheckIn, bool, error) {
	var row model.UserCheckIn
	err := t.tx.Where("user_id = ?", userID).Order("check_in_date DESC").First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserCheckIn{}, false, nil
	}
	return row, err == nil, err
}

func (t *txWrapper) FindCheckInReward(consecutiveDays int) (model.CheckInReward, bool, error) {
	var row model.CheckInReward
	err := t.tx.Where("consecutive_days <= ?", consecutiveDays).
		Order("consecutive_days DESC").First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.CheckInReward{}, false, nil
	}
	return row, err == nil, err
}

func (t *txWrapper) CreateCheckIn(record *model.UserCheckIn) error {
	return t.tx.Create(record).Error
}

func (t *txWrapper) Commit() error { return t.tx.Commit().Error }

func (t *txWrapper) Rollback() error { return t.tx.Rollback().Error }

func (t *txWrapper) DB() *gorm.DB { return t.tx }
