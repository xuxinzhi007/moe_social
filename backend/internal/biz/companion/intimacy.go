package companionbiz

import (
	"math"
	"strings"
)

// 亲密度增量（一期轻量成长，避免一次聊天上满）。
const (
	IntimacyDeltaChat = 2.0
	IntimacyDeltaCare = 1.0
	intimacyScoreMax  = 100.0
	intimacyScoreMin  = 0.0
	relationshipMaxLv = 10
)

// IntimacyDeltaForReason 将互动原因映射为增量；未知原因返回 0。
func IntimacyDeltaForReason(reason string) float64 {
	switch strings.TrimSpace(strings.ToLower(reason)) {
	case "chat":
		return IntimacyDeltaChat
	case "care", "feed", "pet":
		return IntimacyDeltaCare
	default:
		return 0
	}
}

// ClampIntimacyScore 将分数限制在 [0, 100]。
func ClampIntimacyScore(score float64) float64 {
	if math.IsNaN(score) || score < intimacyScoreMin {
		return intimacyScoreMin
	}
	if score > intimacyScoreMax {
		return intimacyScoreMax
	}
	return score
}

// RelationshipLevelFromIntimacy 按每 10 点亲密 +1 级（1–10）。
func RelationshipLevelFromIntimacy(score float64) int {
	s := ClampIntimacyScore(score)
	level := 1 + int(s)/10
	if level > relationshipMaxLv {
		return relationshipMaxLv
	}
	if level < 1 {
		return 1
	}
	return level
}

// ApplyIntimacyDelta 返回新的亲密度与关系等级。
func ApplyIntimacyDelta(current float64, delta float64) (score float64, level int) {
	score = ClampIntimacyScore(current + delta)
	level = RelationshipLevelFromIntimacy(score)
	return score, level
}
