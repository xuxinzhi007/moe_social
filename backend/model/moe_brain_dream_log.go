package model

import "time"

// MoeBrainDreamLog Bot 记忆 RPG「入梦」 consolidation 会话记录。
type MoeBrainDreamLog struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	AgentKey  string    `gorm:"size:64;not null;index" json:"agent_key"`
	Summary   string    `gorm:"type:text" json:"summary"`
	Refined   int       `gorm:"default:0" json:"refined"`
	Merged    int       `gorm:"default:0" json:"merged"`
	Archived  int       `gorm:"default:0" json:"archived"`
	XPGained  int       `gorm:"default:0" json:"xp_gained"`
	CreatedAt time.Time `gorm:"index" json:"created_at"`
}

func (MoeBrainDreamLog) TableName() string {
	return "moe_brain_dream_logs"
}
