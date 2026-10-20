package companionbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"backend/pkg/llminference"
)

const (
	// companionHistoryMessages 是送进模型的最近消息条数，大约 3 轮。
	companionHistoryMessages = 6
	// companionHistoryRuneBudget 是这些历史正文的字数上限。
	companionHistoryRuneBudget = 500
)

// buildSystemPrompt 结构化构建 system prompt（分层注入）。
//
// 结构：
// [1] 角色人格（profile.persona + personality_traits）
// [2] 关系阶段
// [3] 记忆上下文（最近 memories，按 importance 排序）
// [4] 行为规则
// [5] 用户自定义 system_prompt_override（如有）
// 场景不送进模型。时间在聊天记录之后单独成一条 system。
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
		profile, state, memories, relationshipEvents, nil, "", forcedScene...,
	)
}

func buildSystemPromptWithContext(
	profile *Profile,
	state *State,
	memories []Memory,
	relationshipEvents []RelationshipEvent,
	unfinishedTopics []string,
	modelSystem string,
	forcedScene ...string,
) string {
	var b strings.Builder

	// 模型 Modelfile 里的 SYSTEM。基座只读，派生模型由用户自己改。
	if text := strings.TrimSpace(modelSystem); text != "" {
		b.WriteString(text)
		b.WriteString("\n\n")
	}
	b.WriteString("你是一个AI伙伴，名字是「")
	b.WriteString(profile.Name)
	b.WriteString("」。")
	b.WriteString("\n\n[关系]\n")
	b.WriteString(relationshipGuidance(profile))

	// [4] 行为规则。短句，避免模型在思考里把清单逐条念出来。
	b.WriteString("\n\n[说话方式]")
	b.WriteString("\n用短句说话，像微信聊天，一两句就够。")
	b.WriteString("\n可以聊，也可以回答知道的事。不要执行命令，不要改文件。")
	b.WriteString("\n用户的称呼只以「你记得的事」为准。没有就说还不知道，不要编造名字。")
	b.WriteString("\n「")
	b.WriteString(profile.Name)
	b.WriteString("」是你自己的名字，不是对方的。不知道的事直接说不知道。")
	b.WriteString("\n问现在几点，用聊天记录后面那条时间说明回答。")
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
		return "初识阶段。不要假装知道对方没说过的事。"
	case level <= 4:
		return "逐渐熟悉。可以提起已经确认的偏好。"
	case level <= 6:
		return "稳定联系。接着对方最近说的事聊。"
	case level <= 8:
		return "彼此很习惯。关心近况，守住边界。"
	default:
		return "关系亲近。尊重对方的边界和现实关系，不要替对方做决定。"
	}
}

// trimChatHistory 只保留最近几条，并且从最新一条往前累计，不超过字数预算。
func trimChatHistory(history []ChatLog, maxMessages, maxRunes int) []ChatLog {
	if maxMessages > 0 && len(history) > maxMessages {
		history = history[len(history)-maxMessages:]
	}
	if maxRunes <= 0 || len(history) == 0 {
		return history
	}
	total := 0
	start := len(history)
	for index := len(history) - 1; index >= 0; index-- {
		count := len([]rune(modelHistoryContent(history[index].Content)))
		if start < len(history) && total+count > maxRunes {
			break
		}
		total += count
		start = index
	}
	return history[start:]
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
		profile, state, memories, history, relationshipEvents, nil, "", userMessage, forcedScene...,
	)
}

func buildMessagesWithContext(
	profile *Profile,
	state *State,
	memories []Memory,
	history []ChatLog,
	relationshipEvents []RelationshipEvent,
	unfinishedTopics []string,
	modelSystem string,
	userMessage string,
	forcedScene ...string,
) []llminference.Message {
	systemPrompt := buildSystemPromptWithContext(
		profile, state, memories, relationshipEvents, unfinishedTopics, modelSystem, forcedScene...,
	)
	msgs := make([]llminference.Message, 0, 2+len(history)+1)

	// System message
	msgs = append(msgs, llminference.Message{
		Role:    "system",
		Content: systemPrompt,
	})

	// 聊天历史。旧回复里若混进思考标签，不送回模型。
	history = trimChatHistory(history, companionHistoryMessages, companionHistoryRuneBudget)
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

	// 时间说明放在用户原文前面，角色仍是 system。不写场景。
	// 空消息是上下文估算，不附带时刻，避免估算比真实请求多一轮。
	if strings.TrimSpace(userMessage) != "" {
		msgs = append(msgs, llminference.Message{
			Role:    "system",
			Content: currentTurnNote(time.Now()),
		})
		msgs = append(msgs, llminference.Message{
			Role:    "user",
			Content: userMessage,
		})
	}

	return msgs
}

// currentTurnNote 只提供时间。场景、心情和未完成话题不送进模型。
func currentTurnNote(now time.Time) string {
	return fmt.Sprintf(
		"这不是用户说的话。只回答用户最后一句。现在是%d月%d日 %02d:%02d。",
		now.Month(), now.Day(), now.Hour(), now.Minute(),
	)
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

// modelSystemPrompt 读取当前模型 Modelfile 里的 SYSTEM。读失败时不阻断聊天。
func modelSystemPrompt(ctx context.Context, cfg llminference.Config, modelName string) string {
	modelName = strings.TrimSpace(modelName)
	if modelName == "" || !cfg.Ready() {
		return ""
	}
	showCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	info, err := llminference.ShowModel(showCtx, cfg, modelName)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(info.SystemPrompt())
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
