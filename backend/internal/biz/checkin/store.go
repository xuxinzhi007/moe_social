package checkinbiz

import (
	"context"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// CheckInStore 签到持久化（P4-D2；默认由 internal/data/checkin 实现）。
type CheckInStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) CheckInStore

	GetUser(ctx context.Context, userID uint) (model.User, error)
	UserExists(ctx context.Context, userID uint) error
	FindTodayCheckIn(ctx context.Context, userID uint, dayStart, dayEnd time.Time) (model.UserCheckIn, bool, error)
	FindLastCheckIn(ctx context.Context, userID uint) (model.UserCheckIn, bool, error)
	FindCheckInReward(ctx context.Context, consecutiveDays int) (model.CheckInReward, bool, error)
	CreateCheckIn(ctx context.Context, record *model.UserCheckIn) error
	ListCheckIns(ctx context.Context, userID uint, page, pageSize int32) ([]model.UserCheckIn, int64, error)
	CountExpLogs(ctx context.Context, userID uint) (int64, error)
	ListExpLogs(ctx context.Context, userID uint, page, pageSize int32) ([]model.ExpLog, error)
	HasExpLogToday(ctx context.Context, userID uint, source string, dayStart, dayEnd time.Time) (bool, error)
	GetUserLevel(ctx context.Context, userID uint) (model.UserLevel, bool, error)
	CreateUserLevel(ctx context.Context, row *model.UserLevel) error
	GetLevelConfig(ctx context.Context, level int) (model.LevelConfig, bool, error)

	Begin(ctx context.Context) (CheckInTx, error)
}

// CheckInTx 签到事务。
type CheckInTx interface {
	GetUser(userID uint) (model.User, error)
	FindTodayCheckIn(userID uint, dayStart, dayEnd time.Time) (model.UserCheckIn, bool, error)
	FindLastCheckIn(userID uint) (model.UserCheckIn, bool, error)
	FindCheckInReward(consecutiveDays int) (model.CheckInReward, bool, error)
	CreateCheckIn(record *model.UserCheckIn) error
	HasExpLogToday(userID uint, source string, dayStart, dayEnd time.Time) (bool, error)
	Commit() error
	Rollback() error
	DB() *gorm.DB
}
