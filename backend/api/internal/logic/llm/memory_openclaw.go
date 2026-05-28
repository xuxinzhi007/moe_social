package llm

import (
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/types"
	"backend/pkg/memory"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

const sourcePreCompactFlush = "pre_compact_flush"

// buildOpenClawMemoryBlock 按 OpenClaw 分层注入：精选画像 → 今日/昨日日记 → 检索命中。
func buildOpenClawMemoryBlock(
	memories []*moe.UserMemory,
	profiles []*moe.UserMemoryProfile,
	messages []types.LlmMessage,
) string {
	records := memory.RecordsFromSuper(memories)
	query := lastUserMessageContent(messages)

	profileSummaries := make([]memory.ProfileSummary, 0, len(profiles))
	for _, p := range profiles {
		if p == nil || strings.TrimSpace(p.Summary) == "" {
			continue
		}
		profileSummaries = append(profileSummaries, memory.ProfileSummary{
			MemoryType: p.MemoryType,
			Summary:    p.Summary,
			ItemCount:  int(p.ItemCount),
			Confidence: p.Confidence,
		})
	}

	curated := memory.ExcludeDailyNotes(records)
	searchRes := memory.SearchFacing(curated, query, memory.DefaultBootstrapBudget().MaxSearchItems)
	daily := memory.RecentDailyNotes(records, time.Now().UTC())

	return memory.ComposeBootstrap(memory.BootstrapInput{
		Profiles:    profileSummaries,
		DailyNotes:  daily,
		SearchItems: searchRes.Items,
		Budget:      memory.DefaultBootstrapBudget(),
	})
}

func lastUserMessageContent(messages []types.LlmMessage) string {
	for i := len(messages) - 1; i >= 0; i-- {
		if strings.TrimSpace(messages[i].Role) != "user" {
			continue
		}
		return strings.TrimSpace(messages[i].Content)
	}
	return ""
}

// memoryFlushBeforeCompact 在对话压缩/摘要前落盘事实（OpenClaw memory flush）。
func (l *ChatLogic) memoryFlushBeforeCompact(
	userID, sessionID, sourceMsgID string,
	segment []llmChatMessage,
) {
	if strings.TrimSpace(userID) == "" || len(segment) == 0 {
		return
	}
	logger := logx.WithContext(l.ctx)

	for _, m := range segment {
		if m.Role != "user" {
			continue
		}
		for _, item := range memory.HeuristicExtractFromUserMessage(m.Content) {
			_, err := l.svcCtx.LLMGW.UpsertUserMemory(l.ctx, &moe.UpsertUserMemoryReq{
				UserId:      userID,
				Key:         item.Key,
				Value:       item.Value,
				MemoryType:  item.MemoryType,
				Confidence:  0.75,
				Source:      sourcePreCompactFlush,
				SourceMsgId: sourceMsgID,
				SessionId:   sessionID,
			})
			if err != nil {
				logger.Errorf("pre_compact_flush heuristic upsert failed key=%s: %v", item.Key, err)
			}
		}
	}

	l.appendDailyObservation(userID, sessionID, sourceMsgID, segment)

	invalidateCachedUserMemories(userID)

	model := l.memoryExtractModel()
	baseURL := l.inferenceBaseURL()
	go func(uid, sid, msgID, mdl, base string, msgs []llmChatMessage) {
		bgCtx, cancel := backgroundMemoryExtractContext(60)
		defer cancel()
		l.extractAndSaveMemoriesWithSource(bgCtx, uid, mdl, base, 60, sid, msgID, msgs, sourcePreCompactFlush)
	}(userID, sessionID, sourceMsgID, model, baseURL, segment)
}

func (l *ChatLogic) appendDailyObservation(userID, sessionID, sourceMsgID string, segment []llmChatMessage) {
	var userSnippet, assistantSnippet string
	for i := len(segment) - 1; i >= 0; i-- {
		if assistantSnippet == "" && segment[i].Role == "assistant" {
			assistantSnippet = truncateRunes(strings.TrimSpace(segment[i].Content), 120)
		}
		if userSnippet == "" && segment[i].Role == "user" {
			userSnippet = truncateRunes(strings.TrimSpace(segment[i].Content), 80)
		}
		if userSnippet != "" && assistantSnippet != "" {
			break
		}
	}
	if userSnippet == "" && assistantSnippet == "" {
		return
	}
	line := "对话片段"
	if userSnippet != "" {
		line += " 用户:" + userSnippet
	}
	if assistantSnippet != "" {
		line += " 助手:" + assistantSnippet
	}

	key := memory.DailyNoteKey(time.Now().UTC())
	existing := ""
	if resp, err := l.svcCtx.LLMGW.GetUserMemories(l.ctx, &moe.GetUserMemoriesReq{
		UserId: userID,
		Limit:  200,
	}); err == nil {
		for _, m := range resp.Memories {
			if m != nil && m.Key == key {
				existing = m.Value
				break
			}
		}
	}
	merged := memory.MergeDailyNoteContent(existing, line)
	_, _ = l.svcCtx.LLMGW.UpsertUserMemory(l.ctx, &moe.UpsertUserMemoryReq{
		UserId:      userID,
		Key:         key,
		Value:       merged,
		MemoryType:  "observation",
		Confidence:  0.5,
		Source:      sourcePreCompactFlush,
		SourceMsgId: sourceMsgID,
		SessionId:   sessionID,
	})
}

func truncateRunes(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max]) + "…"
}

func (l *ChatLogic) memoryExtractModel() string {
	m := strings.TrimSpace(l.svcCtx.Config.LLMInference.MemoryModel)
	return m
}

func (l *ChatLogic) inferenceBaseURL() string {
	cfg, err := common.InferenceFromLLMConf(l.svcCtx.Config.LLMInference)
	if err != nil {
		return ""
	}
	return cfg.BaseURL
}
