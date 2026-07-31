package model

import "time"

// LifeDailyClaim 背包每日签到领取记录（每用户每天一行）。
type LifeDailyClaim struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    string    `gorm:"size:64;not null;uniqueIndex:idx_life_daily_claim_user_date" json:"user_id"`
	ClaimDate string    `gorm:"size:10;not null;uniqueIndex:idx_life_daily_claim_user_date" json:"claim_date"` // YYYY-MM-DD
	ItemCount int       `gorm:"not null;default:0" json:"item_count"`
	CreatedAt time.Time `json:"created_at"`
}

func (LifeDailyClaim) TableName() string { return "life_daily_claim" }
