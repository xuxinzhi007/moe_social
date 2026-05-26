package model

import "time"

// MoeToolCall AI 工具调用审计与统计（Moe Core v1）。
type MoeToolCall struct {
	ID               uint      `gorm:"primarykey" json:"id"`
	Tool             string    `gorm:"size:64;not null;index" json:"tool"`
	ActorUserID      uint      `gorm:"index" json:"actor_user_id"`
	BotUserID        uint      `json:"bot_user_id"`
	AgentKey         string    `gorm:"size:64;index" json:"agent_key"`
	Ok               bool      `gorm:"index" json:"ok"`
	ErrorMsg         string    `gorm:"size:512" json:"error_msg"`
	LatencyMs        int       `json:"latency_ms"`
	Source           string    `gorm:"size:16;default:api;index" json:"source"`
	IdempotencyKey   string    `gorm:"size:64;index" json:"idempotency_key"`
	ArgumentsPreview string    `gorm:"size:256" json:"arguments_preview"`
	CreatedAt        time.Time `gorm:"index" json:"created_at"`
}

func (MoeToolCall) TableName() string {
	return "moe_tool_calls"
}
