package brain

import (
	"sort"
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

// GenerationPolicy 是稳定度参与发帖决策后的确定性策略。
// 低稳定度不再只改变提示词，而会提高可注入记忆的质量门槛、收紧重试预算，
// 并禁止以放宽质检的候选内容直接发布。
type GenerationPolicy struct {
	StabilityScore       int
	MinMemoryQuality     int
	MaxGenerateAttempts  int
	AllowRelaxedFallback bool
}

// GenerationPolicyForStability 将稳定度映射为生成策略。分档保持可审计，避免隐式魔数散落在运行逻辑中。
func GenerationPolicyForStability(score int) GenerationPolicy {
	score = clampStability(score)
	switch {
	case score < 50:
		return GenerationPolicy{StabilityScore: score, MinMemoryQuality: 80, MaxGenerateAttempts: 3}
	case score < 65:
		return GenerationPolicy{StabilityScore: score, MinMemoryQuality: 70, MaxGenerateAttempts: 4}
	default:
		return GenerationPolicy{StabilityScore: score, MinMemoryQuality: 60, MaxGenerateAttempts: 5, AllowRelaxedFallback: true}
	}
}

// SelectGenerationEpisodes 只选择达到当前稳定度门槛的自传记忆。
// 若没有合格条目，保留质量最高的一条作为最小上下文，避免生成完全失去历史约束。
func SelectGenerationEpisodes(
	episodes []model.MoeBotEpisode,
	forbidden []string,
	policy GenerationPolicy,
	limit int,
) []model.MoeBotEpisode {
	if limit <= 0 || len(episodes) == 0 {
		return nil
	}
	type scoredEpisode struct {
		episode model.MoeBotEpisode
		quality int
	}
	scored := make([]scoredEpisode, 0, len(episodes))
	for _, episode := range episodes {
		scored = append(scored, scoredEpisode{episode: episode, quality: EffectiveQuality(episode, forbidden)})
	}
	accepted := make([]scoredEpisode, 0, len(scored))
	for _, item := range scored {
		if item.quality >= policy.MinMemoryQuality {
			accepted = append(accepted, item)
		}
	}
	if len(accepted) == 0 {
		sort.SliceStable(scored, func(i, j int) bool { return scored[i].quality > scored[j].quality })
		accepted = append(accepted, scored[0])
	}
	if len(accepted) > limit {
		accepted = accepted[:limit]
	}
	out := make([]model.MoeBotEpisode, 0, len(accepted))
	for _, item := range accepted {
		out = append(out, item.episode)
	}
	return out
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
