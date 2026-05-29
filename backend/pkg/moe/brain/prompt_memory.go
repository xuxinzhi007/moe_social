package brain

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"unicode/utf8"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/moe/core"
	"backend/pkg/moe/port"

	llmv1 "backend/api/llm/v1"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

// GenerationMeta 管理端展示：记忆如何进入 Bot 发帖提示词。
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

// BuildPostMemoryBlock 合并用户记忆库与近期自传，注入发帖 LLM 的【Bot 记忆】段。
func BuildPostMemoryBlock(ctx context.Context, db *gorm.DB, rpc port.MoeToolPort, rt model.MoeAgentRuntime) string {
	var sections []string
	if rpc != nil && rt.BotUserID > 0 {
		if block := fetchSyncedMemories(ctx, rpc, rt.BotUserID); block != "" {
			sections = append(sections, "【用户记忆库】\n"+block)
		}
	}
	if db != nil {
		eps := ListRecentEpisodes(db, rt.AgentKey, 8)
		if block := formatEpisodesForPrompt(eps); block != "" {
			sections = append(sections, "【AI大脑自传·近期】\n"+block)
		}
	}
	if len(sections) == 0 {
		return ""
	}
	return strings.Join(sections, "\n\n")
}

// BuildGenerationMeta 供管理端说明记忆是否进入发帖链路。
func BuildGenerationMeta(ctx context.Context, db *gorm.DB, rpc port.MoeToolPort, rt model.MoeAgentRuntime, syncedMemoryCount int) GenerationMeta {
	block := BuildPostMemoryBlock(ctx, db, rpc, rt)
	lines := 0
	if block != "" {
		lines = strings.Count(block, "\n") + 1
	}
	epsInPrompt := 0
	if db != nil {
		n := len(ListRecentEpisodes(db, rt.AgentKey, 8))
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
		MemoriesSynced:     syncedMemoryCount,
		EpisodesInPrompt:   epsInPrompt,
		PromptMemoryLines:  lines,
		PromptPreview:      truncateRunes(block, 480),
		PromptEstTokens:    est,
		ContextLimit:       limit,
		ContextUsedPct:     usedPct,
		Note: "社区 Bot 发帖将记忆写入系统提示词（非 memory_search 工具）。" +
			"「工具与 Bot」页的 memory_* 调用多来自 App 聊天；二者链路不同。",
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

func fetchSyncedMemories(ctx context.Context, rpc port.MoeToolPort, botUserID uint) string {
	if rpc == nil || botUserID == 0 {
		return ""
	}
	uid := strconv.FormatUint(uint64(botUserID), 10)
	memResp, err := rpc.GetUserMemories(ctx, &llmv1.GetUserMemoriesReq{UserId: uid})
	if err != nil || memResp == nil {
		return ""
	}
	records := memory.RecordsFromLLMV1(memResp.GetMemories())
	res := memory.SearchFacing(records, "", 6)
	if len(res.Items) == 0 {
		return ""
	}
	lines := make([]string, 0, len(res.Items))
	for _, it := range res.Items {
		lines = append(lines, fmt.Sprintf("- [%s] %s", it.Key, truncateRunes(it.Content, 80)))
	}
	return strings.Join(lines, "\n")
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
