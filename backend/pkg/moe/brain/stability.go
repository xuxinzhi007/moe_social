package brain

import (
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

const (
	// DefaultStabilityScore 新 Bot 或未迁移记录的初始稳定度。
	DefaultStabilityScore = 70
	stabilityMin          = 1
	stabilityMax          = 100
)

// EffectiveStabilityScore 读取 Bot 稳定度（0 视为默认）。
func EffectiveStabilityScore(rt model.MoeAgentRuntime) int {
	if rt.StabilityScore > 0 {
		return clampStability(rt.StabilityScore)
	}
	return DefaultStabilityScore
}

// ApplyStabilityDelta 增减稳定度并写回数据库。
func ApplyStabilityDelta(db *gorm.DB, agentKey string, delta int) (int, error) {
	if db == nil || strings.TrimSpace(agentKey) == "" {
		return DefaultStabilityScore, nil
	}
	var rt model.MoeAgentRuntime
	if err := db.Where("agent_key = ?", strings.TrimSpace(agentKey)).First(&rt).Error; err != nil {
		return DefaultStabilityScore, err
	}
	next := clampStability(EffectiveStabilityScore(rt) + delta)
	if err := db.Model(&rt).Update("stability_score", next).Error; err != nil {
		return EffectiveStabilityScore(rt), err
	}
	return next, nil
}

func clampStability(v int) int {
	if v < stabilityMin {
		return stabilityMin
	}
	if v > stabilityMax {
		return stabilityMax
	}
	return v
}
