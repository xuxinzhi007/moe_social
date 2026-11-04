// Package replyassistbiz implements judge-first reply suggestions (copy-only).
package replyassistbiz

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
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
)

// ChatMessage is one visible bubble in the conversation snapshot.
type ChatMessage struct {
	Role string
	Text string
}

// SuggestInput is the normalized client payload.
type SuggestInput struct {
	Source     string
	Messages   []ChatMessage
	PastedText string
	ImageURL   string
	AppPackage string
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
	cacheKey := e.cacheKey(userID, normalized)
	if cached, ok := e.loadCache(cacheKey); ok {
		return cached, nil
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

	prompt := buildUserPrompt(normalized)
	messages := []llminference.Message{
		{Role: "system", Content: systemPrompt()},
		{Role: "user", Content: prompt},
	}
	raw, err := llminference.Chat(ctx, cfg, model, messages, llminference.ChatOptions{
		Temperature: 0.35,
	})
	if err != nil {
		return SuggestResult{}, fmt.Errorf("reply assist llm chat: %w", err)
	}
	parsed, err := parseLLMJSON(raw)
	if err != nil {
		return SuggestResult{}, fmt.Errorf("parse reply assist json: %w", err)
	}
	if err := validateResult(parsed); err != nil {
		return SuggestResult{}, err
	}
	if blocked, reason := safetyBlockedReason(parsed); blocked {
		return SuggestResult{}, fmt.Errorf("reply assist safety blocked: %s", reason)
	}

	result := SuggestResult{
		Judge:     parsed.Judge,
		Options:   parsed.Options,
		SessionID: newSessionID(userID, cacheKey),
	}
	e.storeCache(cacheKey, result)
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

	return SuggestInput{
		Source:     source,
		Messages:   msgs,
		PastedText: pasted,
		ImageURL:   strings.TrimSpace(in.ImageURL),
		AppPackage: strings.TrimSpace(in.AppPackage),
	}, nil
}

func systemPrompt() string {
	return strings.TrimSpace(`
你是 Moe Social「回复参谋」的判断与草稿助手。气质：安心表达，帮用户把心里话讲清楚。
禁止：PUA、操控、欺骗、冷战惩罚、物化对方、教「拿捏」、油腻撩法、自动发送暗示。
只输出 JSON，不要 Markdown，不要解释。格式：
{"judge":{"intent":"","emotion":"","urgency":"","reply_stance":"","should_reply":"reply|wait|hold","uncertainty_note":"","risk_hint":""},"options":[{"label":"稳妥","text":""},{"label":"推进","text":""},{"label":"轻松","text":""}]}
要求：options 必须恰好 3 条，label 分别为 稳妥、推进、轻松；文本像真实用户，短句，可直接复制发送；不确定时在 uncertainty_note 说明。`)
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
	b.WriteString("\n请先判断局面，再给出三条不同姿态的中文回复草稿。")
	return b.String()
}

func parseLLMJSON(raw string) (llmPayload, error) {
	trimmed := strings.TrimSpace(raw)
	if i := strings.Index(trimmed, "{"); i >= 0 {
		if j := strings.LastIndex(trimmed, "}"); j > i {
			trimmed = trimmed[i : j+1]
		}
	}
	var payload llmPayload
	if err := json.Unmarshal([]byte(trimmed), &payload); err != nil {
		return llmPayload{}, err
	}
	return payload, nil
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

func (e *Engine) cacheKey(userID uint, in SuggestInput) string {
	h := sha256.New()
	fmt.Fprintf(h, "u=%d|src=%s|pkg=%s|paste=%s", userID, in.Source, in.AppPackage, in.PastedText)
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
