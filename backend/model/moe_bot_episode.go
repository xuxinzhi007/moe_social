package model

import "time"

// MoeBotEpisode Bot 单次发帖「自传」记录（AI 大脑可视化的核心数据）。
type MoeBotEpisode struct {
	ID         uint      `gorm:"primarykey" json:"id"`
	AgentKey   string    `gorm:"size:64;not null;index" json:"agent_key"`
	BotUserID  uint      `gorm:"not null;index" json:"bot_user_id"`
	PostID     string    `gorm:"size:32;index" json:"post_id"`
	Content    string    `gorm:"type:text;not null" json:"content"`
	TagsJSON   string    `gorm:"type:text" json:"tags_json"`
	MoodTag        string    `gorm:"size:32" json:"mood_tag"`
	StyleScore     int       `gorm:"default:0" json:"style_score"`
	QualityScore   int       `gorm:"default:0" json:"quality_score"` // 1-100，越高越被认可
	Approved       bool      `gorm:"default:false" json:"approved"`
	RevisionCount  int       `gorm:"default:0" json:"revision_count"`
	MemoryKey      string    `gorm:"size:128;index" json:"memory_key"`
	Source     string    `gorm:"size:32" json:"source"`
	CreatedAt  time.Time `json:"created_at"`
}

func (MoeBotEpisode) TableName() string {
	return "moe_bot_episodes"
}
