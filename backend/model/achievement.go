package model

import (
	"time"

	"gorm.io/gorm"
)

// Achievement rule types (stored in achievement_definitions.rule_type).
const (
	RuleTypeOnce              = "once"
	RuleTypeCounter           = "counter"
	RuleTypeSum               = "sum"
	RuleTypeMax               = "max"
	RuleTypeTimeWindowCount   = "time_window_count"
	RuleTypeFollowerCount     = "follower_count"
	RuleTypeLevelReached      = "level_reached"
	RuleTypeHanddrawApproved  = "handdraw_approved"
	RuleTypeMoodTagPosts      = "mood_tag_posts"
	RuleTypeDailyComboDays    = "daily_combo_days"
	RuleTypeWeeklyComboWeeks  = "weekly_combo_weeks"
)

// AchievementDefinition 成就徽章配置表
type AchievementDefinition struct {
	ID            string         `gorm:"primaryKey;size:64" json:"id"`
	Name          string         `gorm:"size:100;not null" json:"name"`
	Description   string         `gorm:"size:255" json:"description"`
	Category      string         `gorm:"size:32;not null" json:"category"`
	Rarity        string         `gorm:"size:32;not null" json:"rarity"`
	ConditionText string         `gorm:"size:255" json:"condition_text"`
	RuleType      string         `gorm:"size:64;not null;index" json:"rule_type"`
	RequiredCount int            `gorm:"not null;default:1" json:"required_count"`
	RuleParams    string         `gorm:"type:text" json:"rule_params"`
	ExpReward     int            `gorm:"not null;default:0" json:"exp_reward"`
	Enabled       bool           `gorm:"not null;default:true" json:"enabled"`
	SortOrder     int            `gorm:"not null;default:0" json:"sort_order"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (AchievementDefinition) TableName() string {
	return "achievement_definitions"
}

// UserAchievementProgress 用户成就进度
type UserAchievementProgress struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	UserID       uint           `gorm:"not null;uniqueIndex:uk_user_badge" json:"user_id"`
	BadgeID      string         `gorm:"size:64;not null;uniqueIndex:uk_user_badge" json:"badge_id"`
	CurrentCount int            `gorm:"not null;default:0" json:"current_count"`
	UnlockedAt   *time.Time     `json:"unlocked_at"`
	ExpGranted   bool           `gorm:"not null;default:false" json:"exp_granted"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserAchievementProgress) TableName() string {
	return "user_achievement_progress"
}

// UserDailyActivity 用户每日活跃（日常/周常任务）
type UserDailyActivity struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	UserID       uint           `gorm:"not null;uniqueIndex:uk_user_activity_date" json:"user_id"`
	ActivityDate time.Time      `gorm:"type:date;not null;uniqueIndex:uk_user_activity_date" json:"activity_date"`
	PostCount    int            `gorm:"not null;default:0" json:"post_count"`
	CommentCount int            `gorm:"not null;default:0" json:"comment_count"`
	CheckIn      bool           `gorm:"not null;default:false" json:"check_in"`
	TaskScore    int            `gorm:"not null;default:0" json:"task_score"`
	DailyComboCounted bool        `gorm:"not null;default:false" json:"daily_combo_counted"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserDailyActivity) TableName() string {
	return "user_daily_activity"
}

// UserWeeklyActivity 用户周活跃汇总（周常成就）
type UserWeeklyActivity struct {
	ID            uint           `gorm:"primarykey" json:"id"`
	UserID        uint           `gorm:"not null;uniqueIndex:uk_user_week" json:"user_id"`
	WeekStart     time.Time      `gorm:"type:date;not null;uniqueIndex:uk_user_week" json:"week_start"`
	TaskTotal     int            `gorm:"not null;default:0" json:"task_total"`
	WeeklyCounted bool           `gorm:"not null;default:false" json:"weekly_counted"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (UserWeeklyActivity) TableName() string {
	return "user_weekly_activity"
}
