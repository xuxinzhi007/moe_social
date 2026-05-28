package model

import "time"

// MoeAgentTopicStat Bot 发帖话题/场景使用统计（由规则或 LLM 分析写入，用于避重复）。
type MoeAgentTopicStat struct {
	ID            uint      `gorm:"primarykey" json:"id"`
	AgentKey      string    `gorm:"size:64;not null;uniqueIndex:idx_agent_topic_key" json:"agent_key"`
	TopicKey      string    `gorm:"size:128;not null;uniqueIndex:idx_agent_topic_key" json:"topic_key"`
	Label         string    `gorm:"size:256" json:"label"`
	UseCount      int       `gorm:"default:1" json:"use_count"`
	SampleSnippet string    `gorm:"size:200" json:"sample_snippet"`
	Source        string    `gorm:"size:32" json:"source"`
	LastUsedAt    time.Time `json:"last_used_at"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

func (MoeAgentTopicStat) TableName() string {
	return "moe_agent_topic_stats"
}
