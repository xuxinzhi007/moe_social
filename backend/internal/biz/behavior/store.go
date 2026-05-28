package behaviorbiz

import (
	"context"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// BehaviorStore 行为埋点持久化（P4-D；默认由 internal/data/behavior 实现）。
type BehaviorStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) BehaviorStore

	Transaction(ctx context.Context, fn func(BehaviorTx) error) error
}

// BehaviorTx 行为事件写操作事务。
type BehaviorTx interface {
	CreateBehaviorEvent(row *model.UserBehaviorEvent) error
	FindBehaviorDaily(userID uint, activityDate time.Time, screen string) (model.UserBehaviorDaily, error)
	CreateBehaviorDaily(daily *model.UserBehaviorDaily) error
	UpdateBehaviorDaily(daily *model.UserBehaviorDaily, durationMs int64) error
}
