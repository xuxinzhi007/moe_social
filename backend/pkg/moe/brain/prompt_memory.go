package brain

import (
	"context"
	"fmt"
	"strings"
	"unicode/utf8"

	"backend/model"
	"backend/pkg/moe/core"
	"backend/pkg/moe/port"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

type GenerationMeta struct {
	PostUsesToolMemory bool    `json:"post_uses_tool_memory"`
	MemoriesSynced     int     `json:"memories_synced"`
	EpisodesInPrompt   int     `json:"episodes_in_prompt"`
	PromptMemoryLines  int     `json:"prompt_memory_lines"`
	PromptPreview      string  `json:"prompt_preview"`
	PromptEstTokens    int     `json:"prompt_est_tokens"`
	ContextLimit       int     `json:"context_limit"`
	ContextUsedPct     float64 `json:"context_used_pct"`
	Note               string  `json:"note"`
}

func BuildPostMemoryBlock(ctx context.Context, db *gorm.DB, rpc port.MoeToolPort, rt model.MoeAgentRuntime) string {
	if db == nil {
		return ""
	}
	all := ListRecentEpisodes(db, rt.AgentKey, 24)
	eps := SelectGenerationEpisodes(
		all,
		ParseTagList(rt.ForbiddenTags),
		GenerationPolicyForStability(EffectiveStabilityScore(rt)),
		8,
	)
	return formatEpisodesForPrompt(eps)
}

func BuildGenerationMeta(ctx context.Context, db *gorm.DB, rpc port.MoeToolPort, rt model.MoeAgentRuntime, syncedMemoryCount int) GenerationMeta {
	block := BuildPostMemoryBlock(ctx, db, rpc, rt)
	lines := 0
	if block != "" {
		lines = strings.Count(block, "\n") + 1
	}
	epsInPrompt := 0
	if db != nil {
		n := len(SelectGenerationEpisodes(
			ListRecentEpisodes(db, rt.AgentKey, 24),
			ParseTagList(rt.ForbiddenTags),
			GenerationPolicyForStability(EffectiveStabilityScore(rt)),
			8,
		))
		if n > 8 {
			epsInPrompt = 8
		} else {
			epsInPrompt = n
		}
	}
	est := core.EstimateTokens(block)
	limit := defaultContextLimit()
	usedPct := 0.0
	if limit > 0 && est > 0 {
		usedPct = float64(est) / float64(limit)
		if usedPct > 1 {
			usedPct = 1
		}
	}
	return GenerationMeta{
		PostUsesToolMemory: false,
		MemoriesSynced:     0,
		EpisodesInPrompt:   epsInPrompt,
		PromptMemoryLines:  lines,
		PromptPreview:      truncateRunes(block, 480),
		PromptEstTokens:    est,
		ContextLimit:       limit,
		ContextUsedPct:     usedPct,
		Note:               "社区 Bot 发帖会结合自传记忆与 Bot 用户画像生成内容。",
	}
}

func defaultContextLimit() int {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return 8192
	}
	if n := v.GetInt("llm_inference.context_tokens"); n > 0 {
		return n
	}
	return 8192
}

func formatEpisodesForPrompt(episodes []model.MoeBotEpisode) string {
	if len(episodes) == 0 {
		return ""
	}
	lines := make([]string, 0, len(episodes))
	for _, ep := range episodes {
		lines = append(lines, fmt.Sprintf(
			"- [%s] %s",
			ep.CreatedAt.Format("01-02"),
			truncateRunes(strings.TrimSpace(ep.Content), 120),
		))
	}
	return strings.Join(lines, "\n")
}

func truncateRunes(s string, max int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	return string([]rune(s)[:max]) + "…"
}
