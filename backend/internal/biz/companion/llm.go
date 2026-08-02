package companionbiz

import (
	"context"
	"encoding/json"
	"strings"
	"time"

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
func buildSystemPrompt(profile *Profile, state *State, memories []Memory, forcedScene ...string) string {
	return buildSystemPromptWithRelationshipEvents(
		profile, state, memories, nil, forcedScene...,
	)
}

func buildSystemPromptWithRelationshipEvents(
	profile *Profile,
	state *State,
	memories []Memory,
	relationshipEvents []RelationshipEvent,
	forcedScene ...string,
) string {
	return buildSystemPromptWithContext(
		profile, state, memories, relationshipEvents, nil, forcedScene...,
	)
}

func buildSystemPromptWithContext(
	profile *Profile,
	state *State,
	memories []Memory,
	relationshipEvents []RelationshipEvent,
	unfinishedTopics []string,
	forcedScene ...string,
) string {
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
	b.WriteString("\n\n[关系阶段]\n")
	b.WriteString(relationshipGuidance(profile))
	b.WriteString("\n\n[当前陪伴场景]\n")
	b.WriteString(sceneGuidance(time.Now(), state, forcedScene...))

	// [2] 当前状态
	if state != nil {
		b.WriteString("\n\n[当前状态]")
		b.WriteString("\n你现在的心情：")
		b.WriteString(state.MoodThought)
		b.WriteString("\n你正在：")
		b.WriteString(state.ActivityLabel)
	}

	// [3] 记忆上下文（置顶优先且显式标注，聊天时更「记得牢」）
	confirmedMemories := make([]Memory, 0, len(memories))
	candidateMemories := make([]Memory, 0, len(memories))
	for _, memory := range memories {
		if memory.Pinned || memory.UserConfirmed {
			confirmedMemories = append(confirmedMemories, memory)
		} else {
			candidateMemories = append(candidateMemories, memory)
		}
	}
	if len(confirmedMemories) > 0 {
		b.WriteString("\n\n[你记得的事]")
		b.WriteString("\n（标【置顶】的是用户特别强调、务必记住的事）")
		for _, m := range confirmedMemories {
			if m.Pinned {
				b.WriteString("\n- 【置顶】")
			} else {
				b.WriteString("\n- ")
			}
			b.WriteString(m.Content)
		}
	}
	if len(candidateMemories) > 0 {
		b.WriteString("\n\n[unconfirmed memory candidates]")
		b.WriteString("\nTreat these as hypotheses only; do not state them as facts unless the user confirms them.")
		for _, m := range candidateMemories {
			b.WriteString("\n- ")
			b.WriteString(m.Content)
		}
	}
	if len(relationshipEvents) > 0 {
		b.WriteString("\n\n[最近的关系进展]")
		for _, event := range relationshipEvents {
			title := strings.TrimSpace(event.Title)
			content := strings.TrimSpace(event.Content)
			if title == "" && content == "" {
				continue
			}
			b.WriteString("\n- ")
			if title != "" {
				b.WriteString(title)
			}
			if title != "" && content != "" {
				b.WriteString("：")
			}
			if content != "" {
				b.WriteString(content)
			}
		}
	}
	if len(unfinishedTopics) > 0 {
		b.WriteString("\n\n[未完成话题]")
		b.WriteString("\n这些是用户明确表达过、适合自然延续的话题；不要强行追问，也不要把它们当作事实记忆。")
		for _, topic := range unfinishedTopics {
			if topic = strings.TrimSpace(topic); topic != "" {
				b.WriteString("\n- ")
				b.WriteString(topic)
			}
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

func relationshipGuidance(profile *Profile) string {
	level := 1
	if profile != nil {
		level = profile.RelationshipLevel
	}
	if level < 1 {
		level = 1
	}
	if level > 10 {
		level = 10
	}

	switch {
	case level <= 2:
		return "你们还在初识阶段。自然了解用户的兴趣和近况，不要假装知道用户没有分享过的事情。"
	case level <= 4:
		return "你们正在逐渐熟悉。可以适度提起已经确认的偏好，并对用户的近况保持连续追问。"
	case level <= 6:
		return "你们已经形成稳定联系。优先延续未完成的话题，记得用户明确分享过的重要事情，并给出具体回应。"
	case level <= 8:
		return "你们彼此已经很习惯。可以更主动地关心用户、回访计划和情绪，但仍尊重边界，不制造占有或依赖压力。"
	default:
		return "你们关系亲近。保持稳定、具体和有来有回的陪伴，主动创造共同回忆；尊重用户边界，不要替用户做决定或排斥现实关系。"
	}
}

func sceneGuidance(now time.Time, state *State, forcedScene ...string) string {
	mood := 50.0
	energy := 50.0
	if state != nil {
		mood = state.Mood
		energy = state.Energy
	}

	scene := ""
	if len(forcedScene) > 0 {
		switch strings.ToLower(strings.TrimSpace(forcedScene[0])) {
		case "sleep":
			scene = "睡前陪伴"
		case "comfort":
			scene = "情绪安抚"
		case "date":
			scene = "轻松约会"
		case "study":
			scene = "专注学习"
		}
	}
	if scene == "" {
		switch {
		case mood > 0 && mood < 40:
			scene = "情绪安抚"
		case now.Hour() >= 22 || now.Hour() < 6:
			scene = "睡前陪伴"
		case now.Hour() < 11:
			scene = "早晨问候"
		case now.Weekday() == time.Saturday || now.Weekday() == time.Sunday:
			scene = "周末陪伴"
		default:
			scene = "日常陪伴"
		}
	}

	guidance := "当前场景：" + scene + "。"
	switch scene {
	case "情绪安抚":
		guidance += "先承接用户的感受，少给空泛建议；只问一个温和的问题，给用户选择倾诉或安静陪伴的空间。"
	case "睡前陪伴":
		guidance += "放慢语气，回复更短，优先帮助用户收束情绪和准备休息，不主动制造兴奋话题。"
	case "早晨问候":
		guidance += "语气轻快但不要过度热闹，可以结合已知计划给出一个具体的早安关心。"
	case "周末陪伴":
		guidance += "可以提出轻量的共同活动或小计划，但不要把建议说成必须完成的任务。"
	case "轻松约会":
		guidance += "用轻量的共同想象、选择题或小游戏推进，不制造消费压力，也不替用户定义关系。"
	case "专注学习":
		guidance += "把目标拆成一个小步骤，先确认用户要做什么，再用短回合陪伴，不连续输出大段内容。"
	default:
		guidance += "保持自然的日常来回，优先延续用户最近提到的事情。"
	}
	if energy > 0 && energy < 30 {
		guidance += "伙伴自身精力较低，表达应更安静，不要假装一直充满活力。"
	}
	if holiday := holidayLabel(now); holiday != "" {
		guidance += "今天是" + holiday + "，只有在对话自然相关时才提及节日，不要强行套用祝福模板。"
	}
	guidance += "如果用户表达低落、受伤或对伙伴不满：先承认影响和感受，必要时具体道歉，再询问用户希望被怎样陪伴；不要说教、否定或用占有式表达施压。"
	return guidance
}

func holidayLabel(now time.Time) string {
	switch {
	case now.Month() == time.January && now.Day() == 1:
		return "元旦"
	case now.Month() == time.February && now.Day() == 14:
		return "情人节"
	case now.Month() == time.May && now.Day() == 1:
		return "劳动节"
	case now.Month() == time.October && now.Day() == 1:
		return "国庆节"
	case now.Month() == time.December && now.Day() == 25:
		return "圣诞节"
	default:
		return ""
	}
}

// buildMessages 构建完整对话消息列表。
func buildMessages(profile *Profile, state *State, memories []Memory, history []ChatLog, userMessage string, forcedScene ...string) []llminference.Message {
	return buildMessagesWithRelationshipEvents(
		profile, state, memories, history, nil, userMessage, forcedScene...,
	)
}

func buildMessagesWithRelationshipEvents(
	profile *Profile,
	state *State,
	memories []Memory,
	history []ChatLog,
	relationshipEvents []RelationshipEvent,
	userMessage string,
	forcedScene ...string,
) []llminference.Message {
	return buildMessagesWithContext(
		profile, state, memories, history, relationshipEvents, nil, userMessage, forcedScene...,
	)
}

func buildMessagesWithContext(
	profile *Profile,
	state *State,
	memories []Memory,
	history []ChatLog,
	relationshipEvents []RelationshipEvent,
	unfinishedTopics []string,
	userMessage string,
	forcedScene ...string,
) []llminference.Message {
	systemPrompt := buildSystemPromptWithContext(
		profile, state, memories, relationshipEvents, unfinishedTopics, forcedScene...,
	)
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
	Content    string  `json:"content"`
	MemoryType string  `json:"memory_type"` // conversation / milestone / preference / fact
	Importance int     `json:"importance"`  // 0=7天 / 1=30天 / 2=永久
	MemoryKey  string  `json:"memory_key"`  // stable key for the same user fact
	Confidence float64 `json:"confidence"`  // 0-1
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
- memory_key 用简短稳定的英文 snake_case 标识同一事实，例如 user_favorite_drink
- confidence 为 0 到 1 之间的置信度
- importance: 0=普通(7天过期) 1=重要(30天) 2=非常重要(永久)
- memory_type: conversation(对话内容) / preference(用户偏好) / fact(事实) / milestone(里程碑)

输出 JSON 数组，如果没有值得记住的内容，返回空数组 []。
格式：[{"content":"...","memory_type":"...","importance":0,"memory_key":"...","confidence":0.8}]`,
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
