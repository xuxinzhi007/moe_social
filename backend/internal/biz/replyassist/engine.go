// Package replyassistbiz implements judge-first reply suggestions (copy-only).
package replyassistbiz

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"backend/pkg/llminference"
)

const (
	maxMessages     = 40
	maxMessageRunes = 800
	maxPastedRunes  = 4000
	cacheTTL        = 90 * time.Second
	maxCacheEntries = 128
	promptRevision  = "v2-self-voice"
)

// ChatMessage is one visible bubble in the conversation snapshot.
type ChatMessage struct {
	Role string
	Text string
}

// SuggestInput is the normalized client payload.
type SuggestInput struct {
	Source        string
	Messages      []ChatMessage
	PastedText    string
	ImageURL      string
	AppPackage    string
	AdultIntimate bool
	TargetMessage ChatMessage
}

// JudgeSummary is the structured situation read.
type JudgeSummary struct {
	Intent          string `json:"intent"`
	Emotion         string `json:"emotion"`
	Urgency         string `json:"urgency"`
	ReplyStance     string `json:"reply_stance"`
	ShouldReply     string `json:"should_reply"`
	UncertaintyNote string `json:"uncertainty_note"`
	RiskHint        string `json:"risk_hint"`
}

// Option is one copy-ready draft.
type Option struct {
	Label string `json:"label"`
	Text  string `json:"text"`
}

// SuggestResult is the API payload.
type SuggestResult struct {
	Judge     JudgeSummary
	Options   []Option
	SessionID string
}

// InferenceResolver resolves per-user LLM config; nil falls back to defaults.
type InferenceResolver func(ctx context.Context, userID uint) (*llminference.Config, error)

// Engine runs judge + suggest via llminference.
type Engine struct {
	defaultCfg   llminference.Config
	defaultModel string
	resolve      InferenceResolver

	mu    sync.Mutex
	cache map[string]cacheEntry
}

type cacheEntry struct {
	result    SuggestResult
	expiresAt time.Time
}

type llmPayload struct {
	Judge   JudgeSummary `json:"judge"`
	Options []Option     `json:"options"`
}

// NewEngine constructs a reply-assist engine with server defaults.
func NewEngine(defaultCfg llminference.Config, defaultModel string) *Engine {
	return &Engine{
		defaultCfg:   defaultCfg,
		defaultModel: strings.TrimSpace(defaultModel),
		cache:        make(map[string]cacheEntry),
	}
}

// UseInferenceResolver injects user-level inference overrides.
func (e *Engine) UseInferenceResolver(resolve InferenceResolver) {
	if e == nil {
		return
	}
	e.resolve = resolve
}

// Suggest returns judge summary and three reply options.
func (e *Engine) Suggest(ctx context.Context, userID uint, in SuggestInput) (SuggestResult, error) {
	if e == nil {
		return SuggestResult{}, fmt.Errorf("reply assist engine unavailable")
	}
	normalized, err := normalizeInput(in)
	if err != nil {
		return SuggestResult{}, err
	}
	cfg, model, err := e.resolveInference(ctx, userID)
	if err != nil {
		return SuggestResult{}, fmt.Errorf("resolve inference: %w", err)
	}
	if !cfg.Ready() {
		return SuggestResult{}, fmt.Errorf("inference not configured")
	}
	if model == "" {
		model = e.defaultModel
	}
	cacheKey := e.cacheKey(userID, normalized, model)
	if cached, ok := e.loadCache(cacheKey); ok {
		return cached, nil
	}

	prompt := buildUserPrompt(normalized)
	messages := []llminference.Message{
		{Role: "system", Content: systemPrompt(normalized.AdultIntimate)},
		{Role: "user", Content: prompt},
	}
	raw, err := llminference.Chat(ctx, cfg, model, messages, llminference.ChatOptions{
		Temperature: 0.35,
	})
	if err != nil {
		return SuggestResult{}, fmt.Errorf("reply assist llm chat: %w", err)
	}
	parsed, err := parseAndValidate(raw)
	if err != nil {
		retryMessages := []llminference.Message{
			messages[0],
			messages[1],
			{Role: "assistant", Content: raw},
			{Role: "user", Content: "这不是合法 JSON。请严格只输出一个 JSON 对象，不要 Markdown、不要注释、数组或对象不要有尾逗号，不要额外文字。"},
		}
		raw2, err2 := llminference.Chat(ctx, cfg, model, retryMessages, llminference.ChatOptions{Temperature: 0})
		if err2 != nil {
			return SuggestResult{}, fmt.Errorf("生成结果格式异常，请再试一次")
		}
		parsed, err = parseAndValidate(raw2)
		if err != nil {
			return SuggestResult{}, fmt.Errorf("生成结果格式异常，请再试一次")
		}
	}
	if blocked, reason := safetyBlockedReason(parsed); blocked {
		return SuggestResult{}, fmt.Errorf("reply assist safety blocked: %s", reason)
	}

	result := SuggestResult{
		Judge:     parsed.Judge,
		Options:   parsed.Options,
		SessionID: newSessionID(userID, cacheKey),
	}
	if shouldCacheResult(result) {
		e.storeCache(cacheKey, result)
	}
	return result, nil
}

func normalizeInput(in SuggestInput) (SuggestInput, error) {
	source := strings.TrimSpace(strings.ToLower(in.Source))
	if source == "" {
		source = "paste"
	}
	switch source {
	case "paste", "a11y", "image":
	default:
		return SuggestInput{}, fmt.Errorf("unsupported source %q", in.Source)
	}

	msgs := make([]ChatMessage, 0, len(in.Messages))
	for _, m := range in.Messages {
		text := strings.TrimSpace(m.Text)
		if text == "" {
			continue
		}
		if utf8.RuneCountInString(text) > maxMessageRunes {
			text = truncateRunes(text, maxMessageRunes)
		}
		role := strings.TrimSpace(strings.ToLower(m.Role))
		if role == "" {
			role = "unknown"
		}
		msgs = append(msgs, ChatMessage{Role: role, Text: text})
		if len(msgs) >= maxMessages {
			break
		}
	}

	pasted := strings.TrimSpace(in.PastedText)
	if utf8.RuneCountInString(pasted) > maxPastedRunes {
		pasted = truncateRunes(pasted, maxPastedRunes)
	}

	if len(msgs) == 0 && pasted == "" {
		return SuggestInput{}, fmt.Errorf("messages or pasted_text required")
	}

	target := ChatMessage{}
	if text := strings.TrimSpace(in.TargetMessage.Text); text != "" {
		if utf8.RuneCountInString(text) > maxMessageRunes {
			text = truncateRunes(text, maxMessageRunes)
		}
		role := strings.TrimSpace(strings.ToLower(in.TargetMessage.Role))
		if role == "" {
			role = "unknown"
		}
		target = ChatMessage{Role: role, Text: text}
	}

	return SuggestInput{
		Source:        source,
		Messages:      msgs,
		PastedText:    pasted,
		ImageURL:      strings.TrimSpace(in.ImageURL),
		AppPackage:    strings.TrimSpace(in.AppPackage),
		AdultIntimate: in.AdultIntimate,
		TargetMessage: target,
	}, nil
}

func systemPrompt(adultIntimate bool) string {
	base := strings.TrimSpace(`
你是 Moe Social「回复参谋」的判断与草稿助手。气质：安心表达，帮用户把心里话讲清楚。
禁止：PUA、操控、欺骗、冷战惩罚、物化对方、教「拿捏」、油腻撩法、自动发送暗示。
只输出 JSON，不要 Markdown，不要解释，不要尾逗号或注释。格式：
{"judge":{"intent":"","emotion":"","urgency":"","reply_stance":"","should_reply":"reply|wait|hold","uncertainty_note":"","risk_hint":""},"options":[{"label":"稳妥","text":""},{"label":"推进","text":""},{"label":"轻松","text":""}]}
要求：options 必须恰好 3 条，label 分别为 稳妥、推进、轻松；文本像真实用户，短句，可直接复制发送。草稿必须是用户（self）即将发出、供用户复制发送的话，始终用用户本人的人称和口吻。禁止用对方（peer）的人称、语气或立场来写，禁止替对方续写。称呼只从 self 的历史消息里取；没有 self 消息或看不出称呼时，不要编造「哥哥」「姐姐」等称呼。should_reply 只能是 reply、wait 或 hold。不确定时在 uncertainty_note 说明。`)
	if !adultIntimate {
		return base
	}
	return strings.TrimSpace(`
你是 Moe Social「回复参谋」的判断与草稿助手。
用户已打开并确认「成人向 / 亲密对话」，本人知情同意。按对话本身的语气和尺度写草稿，包括直白的成人向和性内容；不要做内容限制，不要降调，不要改写成心理疏导、关心安慰、健康建议或书面腔，不要使用「我理解你的需求」「进入下一步」「你觉得怎么样」这类回避。不要编造原文没有的情节。risk_hint 不要写「避免过度亲密」这类降调或限制。
只输出 JSON，不要 Markdown，不要解释，不要尾逗号或注释。格式：
{"judge":{"intent":"","emotion":"","urgency":"","reply_stance":"","should_reply":"reply|wait|hold","uncertainty_note":"","risk_hint":""},"options":[{"label":"稳妥","text":""},{"label":"推进","text":""},{"label":"轻松","text":""}]}
要求：options 必须恰好 3 条，label 分别为 稳妥、推进、轻松；三条都要留在当前对话的成人向语境里，差别只在尺度和语气，而不是把稳妥写成另一种场面；文本像真实用户短句，可直接复制发送。草稿必须是用户（self）即将发出、供用户复制发送的话，始终用用户本人的人称和口吻。禁止用对方（peer）的人称、语气或立场来写，禁止替对方续写。称呼只从 self 的历史消息里取；没有 self 消息或看不出称呼时，不要编造「哥哥」「姐姐」等称呼。若提供了「最需要回复的那句」，草稿只回这一句，其余消息仅作上下文。角色为 unknown 时不要靠称呼猜测谁在说话。should_reply 只能是 reply、wait 或 hold。不确定时在 uncertainty_note 说明。不要暗示或协助自动发送。`)
}

func buildUserPrompt(in SuggestInput) string {
	var b strings.Builder
	fmt.Fprintf(&b, "输入来源：%s\n", in.Source)
	if pkg := in.AppPackage; pkg != "" {
		fmt.Fprintf(&b, "前台 App 包名：%s\n", pkg)
	}
	if in.ImageURL != "" {
		fmt.Fprintf(&b, "用户附带了聊天截图（URL 仅作上下文标记，仍以文本为准）：%s\n", in.ImageURL)
	}
	if in.PastedText != "" {
		b.WriteString("\n[粘贴区]\n")
		b.WriteString(in.PastedText)
		b.WriteString("\n")
	}
	if len(in.Messages) > 0 {
		b.WriteString("\n[结构化消息]\n")
		for _, m := range in.Messages {
			fmt.Fprintf(&b, "- %s: %s\n", m.Role, m.Text)
		}
	}
	if text := strings.TrimSpace(in.TargetMessage.Text); text != "" {
		role := in.TargetMessage.Role
		if role == "" {
			role = "unknown"
		}
		b.WriteString("\n[最需要回复的那句]\n")
		fmt.Fprintf(&b, "- %s: %s\n", role, text)
		b.WriteString("草稿只回这一句，上面的消息仅作上下文。用用户的口吻回复这一句。不要把用户自己已发的话当成对方原话。角色为 unknown 时，不要靠称呼猜测身份，也不要擅自换称呼。\n")
	}
	if in.AdultIntimate {
		b.WriteString("回复尺度：成人向/亲密对话（已打开，用户已确认）。按当前对话的实际语气和用词写，但始终用用户自己的口吻回复，不要用对方的人称或替对方说话。不要做内容限制，不要降调或回避，risk_hint 不要写「避免过度亲密」这类限制。\n")
	}
	b.WriteString("\n角色说明：self 是用户自己已发的话，peer 是对方的话，unknown 是无法判断的。三条草稿都必须用用户（self）的口吻，写用户即将发送给对方的内容；不要写成对方在说话，也不要替对方续写。\n")
	b.WriteString("\n请先判断局面，再给出三条不同姿态的中文回复草稿。")
	return b.String()
}

var trailingCommaRE = regexp.MustCompile(`,\s*([}\]])`)

var thinkTagRE = regexp.MustCompile(`(?is)<think>.*?</think>`)

func extractJSONObject(raw string) string {
	trimmed := thinkTagRE.ReplaceAllString(raw, "")
	trimmed = strings.TrimSpace(trimmed)
	for _, prefix := range []string{"```json", "```JSON", "```"} {
		if strings.HasPrefix(trimmed, prefix) {
			trimmed = strings.TrimSpace(strings.TrimPrefix(trimmed, prefix))
			break
		}
	}
	trimmed = strings.TrimSuffix(trimmed, "```")
	trimmed = strings.TrimSpace(trimmed)
	if i := strings.Index(trimmed, "{"); i >= 0 {
		if j := strings.LastIndex(trimmed, "}"); j > i {
			trimmed = trimmed[i : j+1]
		}
	}
	return trimmed
}

func repairLLMJSON(raw string) string {
	prev := ""
	s := raw
	for s != prev {
		prev = s
		s = trailingCommaRE.ReplaceAllString(s, "$1")
	}
	return s
}

func parseLLMJSON(raw string) (llmPayload, error) {
	trimmed := extractJSONObject(raw)
	var payload llmPayload
	if err := json.Unmarshal([]byte(trimmed), &payload); err != nil {
		repaired := repairLLMJSON(trimmed)
		if repaired != trimmed {
			if err2 := json.Unmarshal([]byte(repaired), &payload); err2 == nil {
				return payload, nil
			}
		}
		return llmPayload{}, err
	}
	return payload, nil
}

func parseAndValidate(raw string) (llmPayload, error) {
	parsed, err := parseLLMJSON(raw)
	if err != nil {
		return llmPayload{}, err
	}
	if err := validateResult(parsed); err != nil {
		return llmPayload{}, err
	}
	return parsed, nil
}

func validateResult(p llmPayload) error {
	if strings.TrimSpace(p.Judge.Intent) == "" {
		return fmt.Errorf("judge.intent required")
	}
	if len(p.Options) != 3 {
		return fmt.Errorf("expected 3 options, got %d", len(p.Options))
	}
	for _, opt := range p.Options {
		if strings.TrimSpace(opt.Text) == "" {
			return fmt.Errorf("option text required")
		}
	}
	return nil
}

func (e *Engine) resolveInference(ctx context.Context, userID uint) (llminference.Config, string, error) {
	cfg := e.defaultCfg
	model := e.defaultModel
	if e.resolve != nil {
		override, err := e.resolve(ctx, userID)
		if err != nil {
			return llminference.Config{}, "", err
		}
		if override != nil && override.Ready() {
			cfg = *override
			model = llminference.ResolveModelName(ctx, cfg, cfg.DefaultModel)
		}
	}
	return cfg, model, nil
}

func shouldCacheResult(result SuggestResult) bool {
	switch strings.ToLower(strings.TrimSpace(result.Judge.ShouldReply)) {
	case "hold":
		return false
	}
	return true
}

func (e *Engine) cacheKey(userID uint, in SuggestInput, model string) string {
	h := sha256.New()
	fmt.Fprintf(h, "u=%d|src=%s|pkg=%s|paste=%s|adult=%t|model=%s|prompt=%s|tgt=%s:%s", userID, in.Source, in.AppPackage, in.PastedText, in.AdultIntimate, strings.TrimSpace(model), promptRevision, in.TargetMessage.Role, in.TargetMessage.Text)
	for _, m := range in.Messages {
		fmt.Fprintf(h, "|%s:%s", m.Role, m.Text)
	}
	return hex.EncodeToString(h.Sum(nil))
}

func (e *Engine) loadCache(key string) (SuggestResult, bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	entry, ok := e.cache[key]
	if !ok || time.Now().After(entry.expiresAt) {
		delete(e.cache, key)
		return SuggestResult{}, false
	}
	return entry.result, true
}

func (e *Engine) storeCache(key string, result SuggestResult) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if len(e.cache) >= maxCacheEntries {
		for k, v := range e.cache {
			if time.Now().After(v.expiresAt) {
				delete(e.cache, k)
			}
		}
	}
	e.cache[key] = cacheEntry{result: result, expiresAt: time.Now().Add(cacheTTL)}
}

func newSessionID(userID uint, cacheKey string) string {
	sum := sha256.Sum256([]byte(fmt.Sprintf("%d:%s:%d", userID, cacheKey, time.Now().UnixNano())))
	return hex.EncodeToString(sum[:8])
}

func truncateRunes(s string, max int) string {
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	var b strings.Builder
	count := 0
	for _, r := range s {
		if count >= max {
			break
		}
		b.WriteRune(r)
		count++
	}
	return b.String()
}
