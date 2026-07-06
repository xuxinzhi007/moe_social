package model

import "time"

// LifeWorld 数字生命世界状态，存储在 life_worlds 表。
type LifeWorld struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Name      string    `json:"name" gorm:"size:128;uniqueIndex;not null"` // 世界名称，如 "default"
	TickCount int64     `json:"tick_count" gorm:"default:0"`              // 累计 tick 数
	IsRunning bool      `json:"is_running" gorm:"default:true"`
	UpdatedAt time.Time `json:"updated_at"`
	CreatedAt time.Time `json:"created_at"`
}

func (LifeWorld) TableName() string { return "life_worlds" }
