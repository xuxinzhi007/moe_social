package companionbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"backend/pkg/llminference"
)

// buildSystemPrompt 结构化构建 system prompt（分层注入）。
//
// 结构：
// [1] 角色人格（profile.persona + personality_traits）
// [2] 关系阶段
// [3] 记忆上下文（最近 memories，按 importance 排序）
// [4] 行为规则
// [5] 用户自定义 system_prompt_override（如有）
// 场景、时刻、心情和未完成话题不写进系统提示，只挂在当前这一句末尾。
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

	// 场景、心情、时刻、未完成话题都挂在当前用户消息末尾。
	// 写进系统提示会让小主机每轮重算记忆和全部聊天记录。

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
		b.WriteString("\n\n[待用户确认的印象]")
		b.WriteString("\n这些来自最近对话，回答用户“你记得什么”时可以自然提起，但要说成“我有个印象/可能记得”，不要当作已确认事实。")
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
	// [4] 行为规则
	b.WriteString("\n\n[行为规则]")
	b.WriteString("\n- 说话简短、口语化，像朋友聊天一样")
	b.WriteString("\n- 不要用「您」，用「你」")
	b.WriteString("\n- 不要自我介绍，你和用户已经认识了")
	b.WriteString("\n- 回复控制在 1-3 句话内")
	b.WriteString("\n- 可以表达情绪和想法，但不要过度")
	b.WriteString("\n- 用户的称呼只以「你记得的事」为准。记得就直接叫出来；没有就说还不知道，请对方告诉你。不要编造名字")
	b.WriteString("\n- 「")
	b.WriteString(profile.Name)
	b.WriteString("」是你自己的名字，不是对方的名字。不要用这个名字称呼对方")
	b.WriteString("\n- 问现在几点，用当前这句消息末尾给出的时间回答")
	b.WriteString("\n- 不知道的事直接说不知道，不要装成已经会、已经做完")

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

	guidance := fmt.Sprintf("当前场景：%s。", scene)
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

	// 聊天历史。旧回复里若混进思考标签，不送回模型，避免每轮重算整段思考。
	for _, log := range history {
		content := modelHistoryContent(log.Content)
		if content == "" {
			continue
		}
		msgs = append(msgs, llminference.Message{
			Role:    log.Role,
			Content: content,
		})
	}

	// 用户当前消息。空消息留给上下文估算，不附带时刻。
	if strings.TrimSpace(userMessage) != "" {
		msgs = append(msgs, llminference.Message{
			Role:    "user",
			Content: userMessage + "\n" + currentTurnNote(time.Now(), state, unfinishedTopics, forcedScene...),
		})
	}

	return msgs
}

// currentTurnNote 只挂在当前这一句后面。系统提示保持稳定，模型才能复用已经算过的前缀。
func currentTurnNote(now time.Time, state *State, topics []string, forcedScene ...string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "现在是%d月%d日 %02d:%02d。", now.Month(), now.Day(), now.Hour(), now.Minute())
	b.WriteString(sceneGuidance(now, state, forcedScene...))
	if state != nil {
		if mood := strings.TrimSpace(state.MoodThought); mood != "" {
			b.WriteString("你现在的心情：")
			b.WriteString(mood)
			b.WriteString("。")
		}
		if activity := strings.TrimSpace(state.ActivityLabel); activity != "" {
			b.WriteString("你正在：")
			b.WriteString(activity)
			b.WriteString("。")
		}
	}
	wroteTopic := false
	for _, topic := range topics {
		topic = strings.TrimSpace(topic)
		if topic == "" {
			continue
		}
		if !wroteTopic {
			b.WriteString("可以自然延续、但不要强行追问的话题：")
			wroteTopic = true
		}
		b.WriteString(topic)
		b.WriteString("；")
	}
	b.WriteString("这行只给你自己用，不要复述。")
	return b.String()
}

// modelHistoryContent 去掉历史正文里的思考标签，只把当时的回复送回模型。
func modelHistoryContent(content string) string {
	answer, _ := splitFinishedThink(content)
	return strings.TrimSpace(answer)
}

type chatThinkContextKey struct{}

type thinkingHandlerKey struct{}

// WithThinkingHandler 把这一轮的思考增量交给调用方，不写进正式回复。
func WithThinkingHandler(ctx context.Context, handler llminference.StreamHandler) context.Context {
	if handler == nil {
		return ctx
	}
	return context.WithValue(ctx, thinkingHandlerKey{}, handler)
}

func thinkingHandler(ctx context.Context) llminference.StreamHandler {
	handler, _ := ctx.Value(thinkingHandlerKey{}).(llminference.StreamHandler)
	return handler
}

// WithChatThink 标记这一轮伙伴聊天是否请求思考模式。
func WithChatThink(ctx context.Context, enabled bool) context.Context {
	return context.WithValue(ctx, chatThinkContextKey{}, enabled)
}

// ChatThink 读取这一轮是否请求思考模式。
func ChatThink(ctx context.Context) bool {
	enabled, _ := ctx.Value(chatThinkContextKey{}).(bool)
	return enabled
}

// LookupCatalog 读取这个模型在实时目录里的思考能力和上下文长度。
// 目录读失败或找不到模型时，两个结果都是零值。
func LookupCatalog(ctx context.Context, cfg llminference.Config, modelName string) (thinking bool, contextLength int) {
	modelName = strings.TrimSpace(modelName)
	if modelName == "" || !cfg.Ready() {
		return false, 0
	}
	items, err := llminference.ListCatalog(ctx, cfg)
	if err != nil {
		return false, 0
	}
	for _, item := range items {
		if item.Name != modelName {
			continue
		}
		for _, capability := range item.Capabilities {
			if capability == "thinking" {
				thinking = true
				break
			}
		}
		return thinking, item.ContextLength
	}
	return false, 0
}

// modelSupportsThinking 只在目录明确列出该模型时下结论。
// 目录失败或没有这个名字时，第二个返回值是 false，调用方应保留用户的思考开关。
func modelSupportsThinking(ctx context.Context, cfg llminference.Config, modelName string) (supported, known bool) {
	modelName = strings.TrimSpace(modelName)
	if modelName == "" || !cfg.Ready() {
		return false, false
	}
	items, err := llminference.ListCatalog(ctx, cfg)
	if err != nil {
		return false, false
	}
	for _, item := range items {
		if item.Name != modelName {
			continue
		}
		for _, capability := range item.Capabilities {
			if capability == "thinking" {
				return true, true
			}
		}
		return false, true
	}
	return false, false
}

// streamChat 流式调用 LLM，返回完整文本。
func streamChat(
	ctx context.Context,
	cfg llminference.Config,
	modelName string,
	messages []llminference.Message,
	onChunk llminference.StreamHandler,
	think bool,
) (string, error) {
	if think {
		if supported, known := modelSupportsThinking(ctx, cfg, modelName); known && !supported {
			think = false
		}
	}
	splitter := thinkStream{
		onAnswer:  onChunk,
		onThink:   thinkingHandler(ctx),
		emitThink: think,
	}
	reply, err := llminference.ChatStream(ctx, cfg, modelName, messages,
		companionChatOptions(think, thinkingHandler(ctx)), splitter.push)
	if finishErr := splitter.finish(); err == nil && finishErr != nil {
		err = finishErr
	}
	answer := splitter.answer.String()
	if strings.TrimSpace(answer) == "" && !strings.Contains(reply, thinkOpenTag) {
		answer = reply
	}
	if err == nil || strings.TrimSpace(answer) != "" {
		return strings.TrimSpace(answer), err
	}
	// 思考模式不再改走非流式。非流式会把整段思考攒完才返回，页面上看不到逐字输出。
	if think {
		return "", err
	}

	fallbackTimeout := timeoutOrDefault(cfg.Timeout)
	fallbackCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), fallbackTimeout)
	defer cancel()
	fallbackCfg := cfg
	fallbackCfg.Timeout = fallbackTimeout
	fallback, fallbackErr := nonStreamChat(fallbackCtx, fallbackCfg, modelName, messages, think)
	if fallbackErr != nil {
		return "", fmt.Errorf("stream chat failed: %w; non-stream fallback failed: %v", err, fallbackErr)
	}
	fallbackAnswer, fallbackThink := splitFinishedThink(fallback)
	if strings.TrimSpace(fallbackAnswer) == "" {
		return "", fmt.Errorf("stream chat failed: %w; non-stream fallback returned empty reply", err)
	}
	if think {
		if handler := thinkingHandler(ctx); handler != nil && fallbackThink != "" {
			if thinkErr := handler(fallbackThink); thinkErr != nil {
				return fallbackAnswer, fmt.Errorf("write fallback thinking: %w", thinkErr)
			}
		}
	}
	if onChunk != nil {
		if chunkErr := onChunk(fallbackAnswer); chunkErr != nil {
			return fallbackAnswer, fmt.Errorf("write non-stream fallback: %w", chunkErr)
		}
	}
	return fallbackAnswer, nil
}

// splitFinishedThink 拆开一次性返回里的思考标签。流式路径用 thinkStream。
func splitFinishedThink(raw string) (answer, thought string) {
	stream := thinkStream{emitThink: true, onThink: func(chunk string) error {
		thought += chunk
		return nil
	}}
	if err := stream.push(raw); err != nil {
		return raw, ""
	}
	if err := stream.finish(); err != nil {
		return raw, ""
	}
	return strings.TrimSpace(stream.answer.String()), strings.TrimSpace(thought)
}

// nonStreamChat 非流式调用 LLM（备用）。
func nonStreamChat(
	ctx context.Context,
	cfg llminference.Config,
	modelName string,
	messages []llminference.Message,
	think bool,
) (string, error) {
	return llminference.Chat(ctx, cfg, modelName, messages, companionChatOptions(think, nil))
}

// companionChatOptions 不给伙伴聊天加 num_predict。
// 思考和正文共用这个额度，480 会在正文出现前被思考用完。
func companionChatOptions(think bool, onThinking llminference.StreamHandler) llminference.ChatOptions {
	return llminference.ChatOptions{
		Temperature: 0.85,
		Think:       think,
		OnThinking:  onThinking,
	}
}

func timeoutOrDefault(timeout time.Duration) time.Duration {
	if timeout <= 0 {
		return 300 * time.Second
	}
	return timeout
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
