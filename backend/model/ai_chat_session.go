package model

import "time"

// AiChatSession App 侧 LLM 对话会话（日志与审计，非模型 KV cache）。
type AiChatSession struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	UserID    uint      `gorm:"not null;index:idx_ai_chat_user_session,unique" json:"user_id"`
	SessionID string    `gorm:"size:64;not null;index:idx_ai_chat_user_session,unique" json:"session_id"`
	Model     string    `gorm:"size:128" json:"model"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `gorm:"index" json:"updated_at"`
}

func (AiChatSession) TableName() string {
	return "ai_chat_sessions"
}

// AiChatMessage 单轮对话记录。
type AiChatMessage struct {
	ID          uint      `gorm:"primarykey" json:"id"`
	UserID      uint      `gorm:"not null;index:idx_ai_chat_msg_user" json:"user_id"`
	SessionID   string    `gorm:"size:64;not null;index:idx_ai_chat_msg_session" json:"session_id"`
	SourceMsgID string    `gorm:"size:64;index" json:"source_msg_id"`
	Role        string    `gorm:"size:16;not null" json:"role"`
	Content     string    `gorm:"type:longtext" json:"content"`
	Model       string    `gorm:"size:128" json:"model"`
	CreatedAt   time.Time `gorm:"index" json:"created_at"`
}

func (AiChatMessage) TableName() string {
	return "ai_chat_messages"
}
