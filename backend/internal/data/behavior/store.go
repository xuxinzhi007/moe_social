package behaviordata

import (
	"context"
	"time"

	behaviorbiz "backend/internal/biz/behavior"
	"backend/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.BehaviorStore（P4-D）。
func NewStore(db *gorm.DB) behaviorbiz.BehaviorStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) behaviorbiz.BehaviorStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) Transaction(ctx context.Context, fn func(behaviorbiz.BehaviorTx) error) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return fn(&behaviorTx{tx: tx})
	})
}

type behaviorTx struct {
	tx *gorm.DB
}

func (t *behaviorTx) CreateBehaviorEvent(row *model.UserBehaviorEvent) error {
	return t.tx.Create(row).Error
}

func (t *behaviorTx) FindBehaviorDaily(userID uint, activityDate time.Time, screen string) (model.UserBehaviorDaily, error) {
	var daily model.UserBehaviorDaily
	err := t.tx.Where("user_id = ? AND activity_date = ? AND screen = ?", userID, activityDate, screen).
		First(&daily).Error
	return daily, err
}

func (t *behaviorTx) CreateBehaviorDaily(daily *model.UserBehaviorDaily) error {
	return t.tx.Create(daily).Error
}

func (t *behaviorTx) UpdateBehaviorDaily(daily *model.UserBehaviorDaily, durationMs int64) error {
	return t.tx.Model(daily).Updates(map[string]interface{}{
		"visit_count":       gorm.Expr("visit_count + ?", 1),
		"total_duration_ms": gorm.Expr("total_duration_ms + ?", durationMs),
	}).Error
}

func (t *behaviorTx) UpsertBehaviorDaily(userID uint, activityDate time.Time, screen string, durationMs int64) error {
	daily := model.UserBehaviorDaily{
		UserID:          userID,
		ActivityDate:    activityDate,
		Screen:          screen,
		VisitCount:      1,
		TotalDurationMs: durationMs,
	}
	return t.tx.Clauses(clause.OnConflict{
		Columns: []clause.Column{
			{Name: "user_id"},
			{Name: "activity_date"},
			{Name: "screen"},
		},
		DoUpdates: clause.Assignments(map[string]interface{}{
			"visit_count":       gorm.Expr("visit_count + ?", 1),
			"total_duration_ms": gorm.Expr("total_duration_ms + ?", durationMs),
		}),
	}).Create(&daily).Error
}

var _ behaviorbiz.BehaviorTx = (*behaviorTx)(nil)
