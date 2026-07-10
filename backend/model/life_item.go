package model

import "time"

// LifeItem 道具定义
type LifeItem struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name          string    `gorm:"size:64;not null" json:"name"`
	Icon          string    `gorm:"size:32;default:'📦'" json:"icon"` // emoji 图标
	Description   string    `gorm:"size:256" json:"description"`
	ItemType      string    `gorm:"size:32;not null" json:"item_type"`      // food/toy/medicine/decoration
	EffectKey     string    `gorm:"size:64;not null" json:"effect_key"`     // hunger/energy/mood/experience
	EffectValue   float64   `gorm:"not null;default:10" json:"effect_value"` // 效果数值
	DurationTicks int       `gorm:"default:0" json:"duration_ticks"`        // 持续 tick 数，0=即时效果
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

func (LifeItem) TableName() string { return "life_items" }
