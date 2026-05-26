package brain

import (
	"strings"

	"backend/model"
)

const (
	// QualityApproveThreshold 达到此分数视为「被认可」。
	QualityApproveThreshold = 70
)

// ComputeQualityScore 将内容与标签映射为 1-100 质量分。
func ComputeQualityScore(content, moodTag string, styleScore int, forbidden []string) int {
	tags := ExtractTags(content, moodTag, styleScore)
	score := 88
	score -= styleScore * 14
	for _, t := range tags {
		switch t {
		case "risk:诗意腔":
			score -= 22
		case "type:套路开场":
			score -= 25
		case "risk:过长":
			score -= 8
		}
	}
	if hits := TagsConflict(tags, forbidden); len(hits) > 0 {
		score -= 18 * len(hits)
	}
	if strings.Contains(content, "？") || strings.Contains(content, "吗") {
		score += 3
	}
	if len([]rune(strings.TrimSpace(content))) < 25 {
		score -= 10
	}
	return clampQuality(score)
}

func clampQuality(v int) int {
	if v < 1 {
		return 1
	}
	if v > 100 {
		return 100
	}
	return v
}

// EffectiveQuality 读取 episode 质量分（库内为 0 时按规则重算）。
func EffectiveQuality(ep model.MoeBotEpisode, forbidden []string) int {
	if ep.QualityScore > 0 {
		return ep.QualityScore
	}
	return ComputeQualityScore(ep.Content, ep.MoodTag, ep.StyleScore, forbidden)
}

// IsApprovedQuality 是否达到认可阈值。
func IsApprovedQuality(quality int) bool {
	return quality >= QualityApproveThreshold
}

// NeedsRefinement 是否需要润色迭代。
func NeedsRefinement(quality int, tags, forbidden []string) bool {
	if !IsApprovedQuality(quality) {
		return true
	}
	if len(TagsConflict(tags, forbidden)) > 0 {
		return true
	}
	for _, t := range tags {
		if t == "type:套路开场" || t == "risk:诗意腔" {
			return true
		}
	}
	return false
}
