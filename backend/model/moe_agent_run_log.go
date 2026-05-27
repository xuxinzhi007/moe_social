package model

import "time"

// MoeAgentRunLog Bot 单次试跑/发帖编排步骤（供管理台「处理过程」展示）。
type MoeAgentRunLog struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	AgentKey  string    `gorm:"size:64;not null;index" json:"agent_key"`
	OK        bool      `gorm:"not null" json:"ok"`
	Detail    string    `gorm:"type:text" json:"detail"`
	PostID    string    `gorm:"size:64" json:"post_id"`
	StepsJSON string    `gorm:"type:longtext" json:"steps_json"`
	CreatedAt time.Time `gorm:"index" json:"created_at"`
}

func (MoeAgentRunLog) TableName() string {
	return "moe_agent_run_logs"
}
