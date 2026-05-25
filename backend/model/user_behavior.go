package model

import (
	"time"

	"gorm.io/gorm"
)

// UserBehaviorEvent 用户行为原始事件（页面浏览、关键点击等）。
type UserBehaviorEvent struct {
	ID         uint           `gorm:"primarykey" json:"id"`
	UserID     uint           `gorm:"not null;index:idx_ube_user_created" json:"user_id"`
	Event      string         `gorm:"size:32;not null;index" json:"event"`
	Screen     string         `gorm:"size:64;not null;index" json:"screen"`
	ParamsJSON string         `gorm:"type:text" json:"params_json"`
	DurationMs int64          `gorm:"not null;default:0" json:"duration_ms"`
	SessionID  string         `gorm:"size:64;index" json:"session_id"`
	ClientTs   time.Time      `gorm:"index" json:"client_ts"`
	CreatedAt  time.Time      `gorm:"index:idx_ube_user_created" json:"created_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserBehaviorEvent) TableName() string {
	return "user_behavior_events"
}

// UserBehaviorDaily 用户行为日聚合（按页面维度）。
type UserBehaviorDaily struct {
	ID              uint           `gorm:"primarykey" json:"id"`
	UserID          uint           `gorm:"not null;uniqueIndex:uk_ubd_user_date_screen" json:"user_id"`
	ActivityDate    time.Time      `gorm:"type:date;not null;uniqueIndex:uk_ubd_user_date_screen;index" json:"activity_date"`
	Screen          string         `gorm:"size:64;not null;uniqueIndex:uk_ubd_user_date_screen" json:"screen"`
	VisitCount      int            `gorm:"not null;default:0" json:"visit_count"`
	TotalDurationMs int64          `gorm:"not null;default:0" json:"total_duration_ms"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserBehaviorDaily) TableName() string {
	return "user_behavior_daily"
}
