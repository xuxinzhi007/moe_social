package llmbiz

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"

	llmv1 "backend/api/llm/v1"

	"backend/internal/platform/moelog"
)

// persistChatTurnsAfterReply 将本轮 user/assistant 写入 RPC 会话表（需 session_id）。
func persistChatTurnsAfterReply(
	deps PlatformChatDeps,
	userID, sessionID, sourceMsgID, model string,
	reqMessages []PlatformChatMessage,
	assistantContent string,
) {
	if deps.Gateway == nil || strings.TrimSpace(sessionID) == "" || strings.TrimSpace(userID) == "" {
		return
	}
	lastUser := ""
	for i := len(reqMessages) - 1; i >= 0; i-- {
		if reqMessages[i].Role == "user" && strings.TrimSpace(reqMessages[i].Content) != "" {
			lastUser = reqMessages[i].Content
			break
		}
	}
	if lastUser != "" {
		recordChatTurnAsync(deps, userID, sessionID, sourceMsgID, model, "user", lastUser)
	}
	if strings.TrimSpace(assistantContent) != "" {
		recordChatTurnAsync(deps, userID, sessionID, sourceMsgID, model, "assistant", assistantContent)
	}
}

func recordChatTurnAsync(deps PlatformChatDeps, userID, sessionID, sourceMsgID, model, role, content string) {
	uid, err := strconv.ParseUint(strings.TrimSpace(userID), 10, 64)
	if err != nil || uid == 0 || strings.TrimSpace(sessionID) == "" {
		return
	}
	go func() {
		ctx := context.Background()
		_, _ = deps.Gateway.RecordLlmChatTurn(ctx, &llmv1.RecordLlmChatTurnReq{
			UserId:      uid,
			SessionId:   sessionID,
			SourceMsgId: sourceMsgID,
			Model:       model,
			Role:        role,
			Content:     content,
		})
	}()
}

type memoryItem struct {
	Key        string  `json:"key"`
	Value      string  `json:"value"`
	MemoryType string  `json:"memory_type,omitempty"`
	Confidence float64 `json:"confidence,omitempty"`
	Source     string  `json:"source,omitempty"`
}

func userMemoryAutoLearnEnabled(ctx context.Context, deps PlatformChatDeps, userID string) bool {
	if deps.Gateway == nil || userID == "" {
		return true
	}
	resp, err := deps.Gateway.GetAiUserConfig(ctx, &llmv1.GetAiUserConfigReq{UserId: userID})
	if err != nil || resp == nil {
		return true
	}
	return MemoryAutoLearnEnabled(DecodePreferencesJSON(resp.GetPreferencesJson()))
}

func extractAndSaveMemories(
	ctx context.Context,
	deps PlatformChatDeps,
	userID, model, sessionID, sourceMsgID string,
	history []ChatMessage,
) {
	extractAndSaveMemoriesWithSource(ctx, deps, userID, model, sessionID, sourceMsgID, history, "llm_extract")
}

func extractAndSaveMemoriesWithSource(
	ctx context.Context,
	deps PlatformChatDeps,
	userID, model, sessionID, sourceMsgID string,
	history []ChatMessage,
	source string,
) {
	if strings.TrimSpace(source) == "" {
		source = "llm_extract"
	}
	if !userMemoryAutoLearnEnabled(ctx, deps, userID) {
		return
	}
	if len(history) < 2 || deps.Gateway == nil {
		return
	}

	logger := moelog.WithContext(ctx)

	var sb strings.Builder
	for _, m := range history {
		role := m.Role
		if role == "system" {
			sb.WriteString("[系统信息]: ")
		} else {
			sb.WriteString(role)
			sb.WriteString(": ")
		}
		sb.WriteString(m.Content)
		sb.WriteString("\n")
	}

	prompt := strings.TrimSpace(deps.MemoryExtractPrompt)
	if prompt == "" {
		prompt = defaultMemoryExtractPrompt
	}

	rawContent, chatErr := chatComplete(ctx, deps, model, []ChatMessage{
		{Role: "user", Content: sb.String() + "\n\n" + prompt},
	}, ChatOptions{})
	if chatErr != nil {
		logger.Errorf("extract memory inference failed: %v", chatErr)
		return
	}

	content := strings.TrimSpace(rawContent)
	logger.Infof("memory extraction response received: chars=%d", len([]rune(content)))

	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	if content == "[]" || content == "" {
		return
	}

	var items []memoryItem
	if err := json.Unmarshal([]byte(content), &items); err != nil {
		logger.Errorf("unmarshal memory items failed: %v, chars=%d", err, len([]rune(content)))
		return
	}

	if len(items) > 0 {
		logger.Infof("extracted %d new memories for user %s", len(items), userID)
		for _, item := range items {
			if item.Key == "" || item.Value == "" {
				continue
			}
			_, err := deps.Gateway.UpsertUserMemory(ctx, &llmv1.UpsertUserMemoryReq{
				UserId:      userID,
				Key:         item.Key,
				Value:       item.Value,
				MemoryType:  item.MemoryType,
				Confidence:  item.Confidence,
				Source:      source,
				SourceMsgId: sourceMsgID,
				SessionId:   sessionID,
			})
			if err != nil {
				logger.Errorf("upsert memory %s failed: %v", item.Key, err)
			}
		}
		invalidateCachedUserMemories(userID)
	}
}

const defaultMemoryExtractPrompt = `请分析上述对话，提取关于“用户”（user）的新的、永久性的个人信息（如姓名、昵称、年龄、职业、爱好、位置、重要关系等）。
忽略：
1. [系统信息] 中已有的内容。
2. 临时的状态（如“我饿了”、“我在睡觉”）。
3. 无意义的闲聊。

请严格仅返回一个 JSON 列表，列表项为包含 "key" 和 "value" 的对象。
- key: 使用英文蛇形命名（如 user_name, hobby, profession）。
- value: 用户原本的语言（通常是中文）。
如果没有新信息，请返回空列表 []。

示例输出：
[{"key": "user_name", "value": "小萌"}, {"key": "hobby", "value": "画画"}]

请直接返回 JSON 字符串，不要包含 Markdown 格式（如 code block），不要包含其他解释文字。`

const defaultMemorySummaryPrompt = "你是对话总结助手，需要用简短的中文总结下面的多轮对话，提炼出对后续对话有用的关键信息和记忆点，尽量控制在三到六条以内。"

func summarizeMessages(ctx context.Context, deps PlatformChatDeps, model string, history []ChatMessage) (string, error) {
	if len(history) == 0 {
		return "", nil
	}

	var sb strings.Builder
	for _, m := range history {
		role := m.Role
		if role == "" {
			role = "assistant"
		}
		sb.WriteString(role)
		sb.WriteString("：")
		sb.WriteString(m.Content)
		sb.WriteString("\n")
	}

	systemPrompt := strings.TrimSpace(deps.MemorySummaryPrompt)
	if systemPrompt == "" {
		systemPrompt = defaultMemorySummaryPrompt
	}

	return chatComplete(ctx, deps, model, []ChatMessage{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: sb.String()},
	}, ChatOptions{})
}

func chatComplete(ctx context.Context, deps PlatformChatDeps, model string, messages []ChatMessage, opts ChatOptions) (string, error) {
	if deps.ChatComplete != nil {
		return deps.ChatComplete(ctx, model, messages, opts)
	}
	return PostChatCompletion(ctx, deps.Inference, model, messages, opts)
}
