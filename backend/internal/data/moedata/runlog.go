package moedata

import (
	"backend/model"
	"backend/pkg/moe/runtime"

	"gorm.io/gorm"
)

// LatestAgentRunLog 读取 agent 最近一次试跑日志。
func LatestAgentRunLog(db *gorm.DB, agentKey string) (*model.MoeAgentRunLog, error) {
	return runtime.LatestAgentRunLog(db, agentKey)
}

// ParseRunLog 解析步骤 JSON（兼容旧格式）。
func ParseRunLog(stepsJSON string) runtime.RunLogBundle {
	return runtime.ParseRunLog(stepsJSON)
}
