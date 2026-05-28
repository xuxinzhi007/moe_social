package model

import "time"

// MoeAgentFlowConfig Bot 编排画布布局（节点坐标、连线、视口）；仅配置与可视化。
type MoeAgentFlowConfig struct {
	ID         uint      `gorm:"primaryKey"`
	AgentKey   string    `gorm:"size:64;uniqueIndex;not null"`
	LayoutJSON string    `gorm:"type:text;not null"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

func (MoeAgentFlowConfig) TableName() string {
	return "moe_agent_flow_configs"
}
