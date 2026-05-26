package model

import "time"

// MoeAgentRuntime 社区 AI Bot 运行时配置（Moe Core v1）。
type MoeAgentRuntime struct {
	ID               uint       `gorm:"primarykey" json:"id"`
	AgentKey         string     `gorm:"size:64;uniqueIndex;not null" json:"agent_key"`
	DisplayName      string     `gorm:"size:100" json:"display_name"`
	BotUserID        uint       `gorm:"not null;index" json:"bot_user_id"`
	CapabilityTier   string     `gorm:"size:8;default:s2" json:"capability_tier"`
	ModelName        string     `gorm:"size:128" json:"model_name"`
	ProviderProfileID string    `gorm:"size:128" json:"provider_profile_id"`
	ToolsEnabled     bool       `gorm:"default:true" json:"tools_enabled"`
	PostQuotaDaily   int        `gorm:"default:5" json:"post_quota_daily"`
	PostsToday       int        `gorm:"default:0" json:"posts_today"`
	QuotaResetDate   *time.Time `gorm:"type:date" json:"quota_reset_date,omitempty"`
	LastRunAt        *time.Time `json:"last_run_at,omitempty"`
	LastPostID       string     `gorm:"size:32" json:"last_post_id"`
	Enabled          bool       `gorm:"default:true;index" json:"enabled"`
	SystemPrompt     string     `gorm:"type:text" json:"system_prompt"`
	// PostRules 发帖硬性规则，每行一条（管理后台可编辑，注入 LLM）。
	PostRules        string     `gorm:"type:text" json:"post_rules"`
	// ForbiddenTags / PreferredTags 逗号或换行分隔，如 risk:诗意腔, topic:深夜
	ForbiddenTags    string     `gorm:"type:text" json:"forbidden_tags"`
	PreferredTags    string     `gorm:"type:text" json:"preferred_tags"`
	// PostScheduleMode: manual | cron | smart（smart 预留智能发送）
	PostScheduleMode string     `gorm:"size:16;default:manual;index" json:"post_schedule_mode"`
	ScheduleCron     string     `gorm:"size:64" json:"schedule_cron"`
	NextRunAt        *time.Time `gorm:"index" json:"next_run_at,omitempty"`
	ConfigJSON       string     `gorm:"type:text" json:"config_json"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

func (MoeAgentRuntime) TableName() string {
	return "moe_agent_runtimes"
}
