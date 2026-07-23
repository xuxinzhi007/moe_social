package companionbiz

import (
	"context"
	"encoding/json"
	"strings"

	"backend/pkg/llminference"
)

// buildSystemPrompt 结构化构建 system prompt（分层注入）。
//
// 结构：
// [1] 角色人格（profile.persona + personality_traits）
// [2] 当前状态（state.mood_thought + activity_label）
// [3] 记忆上下文（最近 memories，按 importance 排序）
// [4] 行为规则
// [5] 用户自定义 system_prompt_override（如有）
func buildSystemPrompt(profile *Profile, state *State, memories []Memory) string {
	var b strings.Builder

	// [1] 角色人格
	b.WriteString("你是一个AI伙伴，名字是「")
	b.WriteString(profile.Name)
	b.WriteString("」。")
	if profile.Persona != "" {
		b.WriteString("\n你的性格描述：")
		b.WriteString(profile.Persona)
	}
	if len(profile.PersonalityTraits) > 0 {
		b.WriteString("\n你的性格特点：")
		b.WriteString(strings.Join(profile.PersonalityTraits, "、"))
	}

	// [2] 当前状态
	if state != nil {
		b.WriteString("\n\n[当前状态]")
		b.WriteString("\n你现在的心情：")
		b.WriteString(state.MoodThought)
		b.WriteString("\n你正在：")
		b.WriteString(state.ActivityLabel)
	}

	// [3] 记忆上下文
	if len(memories) > 0 {
		b.WriteString("\n\n[你记得的事]")
		for _, m := range memories {
			b.WriteString("\n- ")
			b.WriteString(m.Content)
		}
	}

	// [4] 行为规则
	b.WriteString("\n\n[行为规则]")
	b.WriteString("\n- 说话简短、口语化，像朋友聊天一样")
	b.WriteString("\n- 不要用「您」，用「你」")
	b.WriteString("\n- 不要自我介绍，你和用户已经认识了")
	b.WriteString("\n- 回复控制在 1-3 句话内")
	b.WriteString("\n- 可以表达情绪和想法，但不要过度")

	// [5] 用户自定义覆盖
	if override := strings.TrimSpace(profile.SystemPromptOverride); override != "" {
		b.WriteString("\n\n[自定义规则]\n")
		b.WriteString(override)
	}

	return b.String()
}

// buildMessages 构建完整对话消息列表。
func buildMessages(profile *Profile, state *State, memories []Memory, history []ChatLog, userMessage string) []llminference.Message {
	systemPrompt := buildSystemPrompt(profile, state, memories)
	msgs := make([]llminference.Message, 0, 2+len(history)+1)

	// System message
	msgs = append(msgs, llminference.Message{
		Role:    "system",
		Content: systemPrompt,
	})

	// 聊天历史
	for _, log := range history {
		msgs = append(msgs, llminference.Message{
			Role:    log.Role,
			Content: log.Content,
		})
	}

	// 用户当前消息
	msgs = append(msgs, llminference.Message{
		Role:    "user",
		Content: userMessage,
	})

	return msgs
}

// streamChat 流式调用 LLM，返回完整文本。
func streamChat(
	ctx context.Context,
	cfg llminference.Config,
	modelName string,
	messages []llminference.Message,
	onChunk llminference.StreamHandler,
) (string, error) {
	return llminference.ChatStream(ctx, cfg, modelName, messages,
		llminference.ChatOptions{
			Temperature: 0.85,
			MaxTokens:   480,
		}, onChunk)
}

// nonStreamChat 非流式调用 LLM（备用）。
func nonStreamChat(
	ctx context.Context,
	cfg llminference.Config,
	modelName string,
	messages []llminference.Message,
) (string, error) {
	return llminference.Chat(ctx, cfg, modelName, messages,
		llminference.ChatOptions{
			Temperature: 0.85,
			MaxTokens:   480,
		})
}

// ── 记忆提取 ──

// extractedMemory LLM 提取的单条记忆。
type extractedMemory struct {
	Content    string `json:"content"`
	MemoryType string `json:"memory_type"` // conversation / milestone / preference / fact
	Importance int    `json:"importance"`  // 0=7天 / 1=30天 / 2=永久
}

// extractMemoryPrompt 构建记忆提取 prompt。
func extractMemoryPrompt(userMsg, assistantReply string) []llminference.Message {
	return []llminference.Message{
		{
			Role: "system",
			Content: `你是一个记忆提取器。根据以下对话，提取值得记住的信息。

规则：
- 仅提取重要信息（用户偏好、重要事实、里程碑、情感事件）
- 日常寒暄（你好、再见、今天天气）不需要记住
- 每条记忆用一句话概括
- importance: 0=普通(7天过期) 1=重要(30天) 2=非常重要(永久)
- memory_type: conversation(对话内容) / preference(用户偏好) / fact(事实) / milestone(里程碑)

输出 JSON 数组，如果没有值得记住的内容，返回空数组 []。
格式：[{"content":"...","memory_type":"...","importance":0}]`,
		},
		{
			Role:    "user",
			Content: "用户说：" + userMsg + "\n伙伴回复：" + assistantReply,
		},
	}
}

// ExtractMemories 从一轮对话中提取记忆。
func ExtractMemories(ctx context.Context, cfg llminference.Config, modelName, userMsg, assistantReply string) ([]extractedMemory, error) {
	if !cfg.Ready() {
		return nil, nil
	}
	msgs := extractMemoryPrompt(userMsg, assistantReply)
	raw, err := llminference.Chat(ctx, cfg, modelName, msgs, llminference.ChatOptions{
		Temperature: 0.3,
		MaxTokens:   300,
	})
	if err != nil {
		return nil, err
	}
	// 提取 JSON 数组（LLM 可能包裹在 markdown code block 中）
	raw = strings.TrimSpace(raw)
	if idx := strings.Index(raw, "["); idx >= 0 {
		raw = raw[idx:]
	}
	if idx := strings.LastIndex(raw, "]"); idx >= 0 {
		raw = raw[:idx+1]
	}
	if raw == "" || raw == "[]" {
		return nil, nil
	}
	var memories []extractedMemory
	if err := json.Unmarshal([]byte(raw), &memories); err != nil {
		return nil, err
	}
	return memories, nil
}
