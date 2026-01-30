package model

import (
	"time"

	"gorm.io/gorm"
)

// UserLevel 用户等级表
type UserLevel struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	UserID       uint           `gorm:"uniqueIndex;not null" json:"user_id"`       // 用户ID
	Level        int            `gorm:"default:1" json:"level"`                    // 当前等级
	Experience   int            `gorm:"default:0" json:"experience"`               // 当前经验值
	TotalExp     int            `gorm:"default:0" json:"total_exp"`                // 累计经验值
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联
	User User `gorm:"foreignKey:UserID" json:"user"`
}

// LevelConfig 等级配置表
type LevelConfig struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	Level       int            `gorm:"uniqueIndex;not null" json:"level"`         // 等级
	Title       string         `gorm:"size:50;not null" json:"title"`             // 等级标题
	MinExp      int            `gorm:"not null" json:"min_exp"`                   // 等级所需最低经验值
	MaxExp      int            `gorm:"not null" json:"max_exp"`                   // 等级经验上限
	Privileges  string         `gorm:"type:text" json:"privileges"`               // 等级特权配置JSON
	BadgeUrl    string         `gorm:"type:text" json:"badge_url"`                // 等级徽章图片URL
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

// UserCheckIn 用户签到记录表
type UserCheckIn struct {
	ID               uint           `gorm:"primarykey" json:"id"`
	UserID           uint           `gorm:"index;not null" json:"user_id"`              // 用户ID
	CheckInDate      time.Time      `gorm:"index;not null" json:"check_in_date"`        // 签到日期
	ConsecutiveDays  int            `gorm:"default:1" json:"consecutive_days"`          // 连续签到天数
	ExpReward        int            `gorm:"default:0" json:"exp_reward"`                // 获得的经验奖励
	IsSpecialReward  bool           `gorm:"default:false" json:"is_special_reward"`     // 是否获得特殊奖励
	SpecialRewardDesc string        `gorm:"type:text" json:"special_reward_desc"`       // 特殊奖励描述
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
	DeletedAt        gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联
	User User `gorm:"foreignKey:UserID" json:"user"`
}

// CheckInReward 签到奖励配置表
type CheckInReward struct {
	ID              uint           `gorm:"primarykey" json:"id"`
	ConsecutiveDays int            `gorm:"uniqueIndex;not null" json:"consecutive_days"` // 连续签到天数
	ExpReward       int            `gorm:"not null" json:"exp_reward"`                   // 经验奖励
	ExtraReward     string         `gorm:"type:text" json:"extra_reward"`                // 额外奖励JSON配置
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

// ExpLog 经验获得日志表
type ExpLog struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	UserID      uint           `gorm:"index;not null" json:"user_id"`        // 用户ID
	ExpChange   int            `gorm:"not null" json:"exp_change"`           // 经验变化量（正数为获得，负数为扣除）
	Source      string         `gorm:"size:50;not null" json:"source"`       // 经验来源：check_in/post/like/comment/vip_bonus等
	SourceID    string         `gorm:"size:100" json:"source_id"`            // 来源关联ID（如帖子ID、评论ID等）
	Description string         `gorm:"size:200" json:"description"`          // 描述
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联
	User User `gorm:"foreignKey:UserID" json:"user"`
}