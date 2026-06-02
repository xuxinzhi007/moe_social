package llmbiz

import (
	"context"
	"fmt"
	"strings"

	llmv1 "backend/api/llm/v1"
	"backend/common/errorcode"

	"backend/internal/platform/moelog"
)

func platformOutcomeOK(content string, ratio float64, summarized bool) PlatformChatOutcome {
	return PlatformChatOutcome{
		Content:        content,
		RemainingRatio: ratio,
		Summarized:     summarized,
		Code:           errorcode.E_SUCCESS,
		Message:        "操作成功",
		Success:        true,
	}
}

func platformOutcomeErr(err error, summarized bool) PlatformChatOutcome {
	if err == nil {
		err = fmt.Errorf("unknown error")
	}
	return PlatformChatOutcome{
		RemainingRatio: 1,
		Summarized:     summarized,
		Code:           errorcode.E_INTERNAL_ERROR,
		Message:        err.Error(),
		Success:        false,
	}
}

// ExecutePlatformChat POST /api/llm/chat 业务入口。
func ExecutePlatformChat(ctx context.Context, deps PlatformChatDeps, in PlatformChatInput) (PlatformChatOutcome, error) {
	budget := memoryBudgetOrDefault(deps.MemoryBudget)
	sessionID := strings.TrimSpace(in.SessionId)
	sourceMsgID := strings.TrimSpace(in.SourceMsgId)

	var memoryBlock string
	userIDForLog := userIDFromContext(ctx)
	if !in.ClientMemoryApplied && userIDForLog != "" && deps.Gateway != nil {
		var memories []*llmv1.UserMemory
		if cached, hit := getCachedUserMemories(userIDForLog); hit {
			memories = cached
			moelog.WithContext(ctx).Infof("memory cache hit user_id=%s total=%d", userIDForLog, len(cached))
		} else {
			rpcResp, err := deps.Gateway.GetUserMemories(ctx, &llmv1.GetUserMemoriesReq{UserId: userIDForLog})
			if err != nil {
				moelog.WithContext(ctx).Errorf("GetUserMemories failed: %v", err)
			} else if rpcResp != nil {
				memories = rpcResp.Memories
				setCachedUserMemories(userIDForLog, memories)
				moelog.WithContext(ctx).Infof("memory cache miss user_id=%s total=%d", userIDForLog, len(memories))
			}
		}
		var profiles []*llmv1.UserMemoryProfile
		if profResp, err := deps.Gateway.GetUserMemoryProfiles(ctx, &llmv1.GetUserMemoryProfilesReq{
			UserId: userIDForLog,
			Limit:  8,
		}); err != nil {
			moelog.WithContext(ctx).Errorf("GetUserMemoryProfiles failed: %v", err)
		} else if profResp != nil {
			profiles = profResp.Profiles
		}
		memoryBlock = buildOpenClawMemoryBlock(memories, profiles, in.Messages)
	} else if in.ClientMemoryApplied && userIDForLog != "" {
		moelog.WithContext(ctx).Infof("memory inject skipped (client_memory_applied), user_id=%s", userIDForLog)
	}

	var clientSystemPrompt string
	clientSystemIndex := -1
	for i, m := range in.Messages {
		if m.Role == "system" {
			clientSystemPrompt = m.Content
			clientSystemIndex = i
			break
		}
	}

	guardrails := conversationGuardrailsFor(clientSystemPrompt)
	systemContent := guardrails
	if clientSystemPrompt != "" {
		systemContent = strings.TrimSpace(clientSystemPrompt) + "\n\n" + guardrails
	}
	if strings.TrimSpace(memoryBlock) != "" {
		systemContent = systemContent + "\n\n" + memoryBlock
	}

	messages := make([]ChatMessage, 0, len(in.Messages)+1)
	messages = append(messages, ChatMessage{Role: "system", Content: systemContent})
	for i, m := range in.Messages {
		if i == clientSystemIndex {
			continue
		}
		messages = append(messages, ChatMessage{Role: m.Role, Content: m.Content})
	}

	if userIDForLog != "" {
		moelog.WithContext(ctx).Infof("llm chat with memory, user_id=%s, model=%s, messages=%d, memory_block_chars=%d",
			userIDForLog, in.Model, len(in.Messages), len([]rune(memoryBlock)))
	} else {
		moelog.WithContext(ctx).Infof("llm chat without memory, model=%s, messages=%d", in.Model, len(in.Messages))
	}

	if strings.TrimSpace(deps.Inference.BaseURL) == "" {
		return platformOutcomeErr(fmt.Errorf("inference config unavailable"), false), nil
	}

	memoryModel := strings.TrimSpace(deps.MemoryModel)
	if memoryModel == "" {
		memoryModel = in.Model
	}

	usedTokens := 0
	for _, m := range messages {
		usedTokens += estimateTokens(m.Content)
	}

	usableTokens := int(float64(budget.MaxCtxTokens) * budget.CtxSafeRatio)
	if usableTokens <= 0 {
		usableTokens = budget.MaxCtxTokens
	}

	if needsExplicitSummary(in.Messages) {
		history := messages[1:]
		if userIDForLog != "" && len(history) > 0 {
			memoryFlushBeforeCompact(ctx, deps, userIDForLog, sessionID, sourceMsgID, history)
		}
		summary, sumErr := summarizeMessages(ctx, deps, memoryModel, history)
		if sumErr == nil && strings.TrimSpace(summary) != "" {
			if userIDForLog != "" {
				fullMessages := append(append([]ChatMessage(nil), messages...), ChatMessage{
					Role: "assistant", Content: summary,
				})
				timeoutSec := int(deps.Inference.Timeout.Seconds())
				go func(uid, sid, msgID, mdl string, msgs []ChatMessage) {
					bgCtx, cancel := backgroundMemoryExtractContext(timeoutSec)
					defer cancel()
					extractAndSaveMemoriesWithSource(bgCtx, deps, uid, mdl, sid, msgID, msgs, "llm_extract")
				}(userIDForLog, sessionID, sourceMsgID, memoryModel, fullMessages)
			}
			ratio := remainingTokenRatio(history, summary, usableTokens)
			return platformOutcomeOK(summary, ratio, true), nil
		}
	}

	summarized := false
	if needAutoSummary(in.Messages, messages, usedTokens, usableTokens, budget) {
		oldEnd := len(messages) - budget.KeepRecentMessages
		if oldEnd <= 1 {
			oldEnd = 1
		}
		oldMessages := make([]ChatMessage, oldEnd-1)
		copy(oldMessages, messages[1:oldEnd])

		if userIDForLog != "" {
			memoryFlushBeforeCompact(ctx, deps, userIDForLog, sessionID, sourceMsgID, oldMessages)
		}

		summary, sumErr := summarizeMessages(ctx, deps, memoryModel, oldMessages)
		if sumErr != nil {
			moelog.WithContext(ctx).Errorf("summarizeMessages failed: %v", sumErr)
		} else if strings.TrimSpace(summary) != "" {
			systemContent = systemContent + "\n\n之前部分对话的简要总结如下，请在理解用户当前消息时一并参考：\n" + summary
			newMessages := make([]ChatMessage, 0, budget.KeepRecentMessages+1)
			newMessages = append(newMessages, ChatMessage{Role: "system", Content: systemContent})
			newMessages = append(newMessages, messages[oldEnd:]...)
			messages = newMessages
			summarized = true
		}
	}

	if in.Stream {
		moelog.WithContext(ctx).Info("llm chat stream requested but only non-stream path is supported; falling back")
	}

	chatOpts := ChatOptions{
		Temperature: in.Temperature,
		TopP:        in.TopP,
		MaxTokens:   in.MaxTokens,
	}

	content, chatErr := chatComplete(ctx, deps, in.Model, messages, chatOpts)
	if chatErr != nil {
		return platformOutcomeErr(fmt.Errorf("调用推理服务失败: %w", chatErr), summarized), nil
	}
	assistantContent := sanitizePersonaResponse(content)

	if userIDForLog != "" && sessionID != "" {
		persistChatTurnsAfterReply(deps, userIDForLog, sessionID, sourceMsgID, in.Model, in.Messages, assistantContent)
	}

	if userIDForLog != "" {
		fullMessages := append(append([]ChatMessage(nil), messages...), ChatMessage{
			Role: "assistant", Content: assistantContent,
		})
		timeoutSec := int(deps.Inference.Timeout.Seconds())
		go func(uid, sid, msgID, mdl string, msgs []ChatMessage) {
			bgCtx, cancel := backgroundMemoryExtractContext(timeoutSec)
			defer cancel()
			extractAndSaveMemoriesWithSource(bgCtx, deps, uid, mdl, sid, msgID, msgs, "llm_extract")
		}(userIDForLog, sessionID, sourceMsgID, memoryModel, fullMessages)
	}

	ratio := remainingTokenRatio(messages, assistantContent, usableTokens)
	return platformOutcomeOK(assistantContent, ratio, summarized), nil
}

func needsExplicitSummary(messages []PlatformChatMessage) bool {
	if len(messages) == 0 {
		return false
	}
	last := messages[len(messages)-1]
	content := strings.TrimSpace(last.Content)
	if content == "" || len([]rune(content)) > 30 {
		return false
	}
	if content == "总结" || content == "概括" || content == "梳理" {
		return true
	}
	keywords := []string{"总结一下", "帮我总结", "整理一下", "帮我整理", "概括一下", "帮我概括", "梳理一下", "帮我梳理"}
	for _, kw := range keywords {
		if strings.Contains(content, kw) {
			return true
		}
	}
	return false
}

func needAutoSummary(
	reqMessages []PlatformChatMessage,
	messages []ChatMessage,
	usedTokens, usableTokens int,
	budget MemoryBudgetConfig,
) bool {
	if len(messages) <= 1+budget.KeepRecentMessages {
		return false
	}
	if len(reqMessages) > budget.MaxHistoryMessages {
		return true
	}
	return usableTokens > 0 && usedTokens > usableTokens
}

func remainingTokenRatio(messages []ChatMessage, assistantContent string, usableTokens int) float64 {
	used := estimateTokens(assistantContent)
	for _, m := range messages {
		used += estimateTokens(m.Content)
	}
	if usableTokens <= 0 {
		return 1
	}
	remaining := usableTokens - used
	if remaining < 0 {
		remaining = 0
	}
	if remaining > usableTokens {
		remaining = usableTokens
	}
	return float64(remaining) / float64(usableTokens)
}
