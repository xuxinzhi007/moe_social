package llmbiz

import (
	"context"
	"strings"
	"time"

	"backend/pkg/memory"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

// buildOpenClawMemoryBlock 按 OpenClaw 分层注入：精选画像 → 今日/昨日日记 → 检索命中。
func buildOpenClawMemoryBlock(
	memories []*moe.UserMemory,
	profiles []*moe.UserMemoryProfile,
	messages []PlatformChatMessage,
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

func lastUserMessageContent(messages []PlatformChatMessage) string {
	for i := len(messages) - 1; i >= 0; i-- {
		if strings.TrimSpace(messages[i].Role) != "user" {
			continue
		}
		return strings.TrimSpace(messages[i].Content)
	}
	return ""
}

func memoryFlushBeforeCompact(
	ctx context.Context,
	deps PlatformChatDeps,
	userID, sessionID, sourceMsgID string,
	segment []ChatMessage,
) {
	if strings.TrimSpace(userID) == "" || len(segment) == 0 || deps.Gateway == nil {
		return
	}
	logger := logx.WithContext(ctx)

	for _, m := range segment {
		if m.Role != "user" {
			continue
		}
		for _, item := range memory.HeuristicExtractFromUserMessage(m.Content) {
			_, err := deps.Gateway.UpsertUserMemory(ctx, &moe.UpsertUserMemoryReq{
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

	appendDailyObservation(ctx, deps, userID, sessionID, sourceMsgID, segment)
	invalidateCachedUserMemories(userID)

	memoryModel := strings.TrimSpace(deps.MemoryModel)
	timeoutSec := int(deps.Inference.Timeout.Seconds())
	go func(uid, sid, msgID, mdl string, msgs []ChatMessage) {
		bgCtx, cancel := backgroundMemoryExtractContext(timeoutSec)
		defer cancel()
		extractAndSaveMemoriesWithSource(bgCtx, deps, uid, mdl, sid, msgID, msgs, sourcePreCompactFlush)
	}(userID, sessionID, sourceMsgID, memoryModel, segment)
}

func appendDailyObservation(
	ctx context.Context,
	deps PlatformChatDeps,
	userID, sessionID, sourceMsgID string,
	segment []ChatMessage,
) {
	if deps.Gateway == nil {
		return
	}
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
	if resp, err := deps.Gateway.GetUserMemories(ctx, &moe.GetUserMemoriesReq{
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
	_, _ = deps.Gateway.UpsertUserMemory(ctx, &moe.UpsertUserMemoryReq{
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
