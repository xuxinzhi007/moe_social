// Package llminference provides OpenAI-compatible and native Ollama inference clients.
package llminference

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// APIStyle selects the upstream protocol.
type APIStyle string

const (
	APIOpenAI APIStyle = "openai"
	APIOllama APIStyle = "ollama"
)

// Config contains trusted server-side endpoint configuration.
type Config struct {
	BaseURL      string
	APIStyle     APIStyle
	Timeout      time.Duration
	DefaultModel string
	APIKey       string
}

// Message is a chat message. Tool fields are used when the model calls functions.
type Message struct {
	Role       string     `json:"role"`
	Content    string     `json:"content,omitempty"`
	ToolCallID string     `json:"tool_call_id,omitempty"`
	ToolCalls  []ToolCall `json:"tool_calls,omitempty"`
}

// ToolCall is one model-requested function call.
type ToolCall struct {
	ID       string           `json:"id,omitempty"`
	Type     string           `json:"type,omitempty"`
	Function ToolCallFunction `json:"function"`
}

// ToolCallFunction is the function name and JSON arguments.
type ToolCallFunction struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

// Tool is an OpenAI-compatible function definition.
type Tool struct {
	Name        string
	Description string
	Parameters  map[string]any
}

// ChatOptions contains sampling parameters.
type ChatOptions struct {
	Temperature   float64
	TopP          float64
	MaxTokens     int
	RepeatPenalty float64
	Tools         []Tool
}

// ConfigFrom normalizes application configuration.
func ConfigFrom(baseURL, apiStyle string, timeoutSec int, defaultModel, apiKey string) Config {
	return Config{BaseURL: strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		APIStyle: ResolveAPIStyle(apiStyle, baseURL), Timeout: timeoutOrDefault(time.Duration(timeoutSec) * time.Second),
		DefaultModel: strings.TrimSpace(defaultModel), APIKey: strings.TrimSpace(apiKey)}
}

// ResolveAPIStyle selects the explicit protocol or infers the legacy Ollama port.
func ResolveAPIStyle(configured, baseURL string) APIStyle {
	switch strings.ToLower(strings.TrimSpace(configured)) {
	case "ollama":
		return APIOllama
	case "openai", "openai_compatible", "llama_cpp", "llamacpp":
		return APIOpenAI
	}
	if strings.Contains(strings.ToLower(baseURL), ":11434") {
		return APIOllama
	}
	return APIOpenAI
}

// Ready reports whether an endpoint is configured; requests validate it separately.
func (c Config) Ready() bool { return strings.TrimSpace(c.BaseURL) != "" }

// Ping probes the model catalog with a short deadline.
func Ping(ctx context.Context, cfg Config) bool {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	models, err := ListModels(ctx, cfg)
	return err == nil && len(models) > 0
}

// ListModels returns the complete catalog, including managed models. Authorization
// of explicitly requested private models belongs to the caller, not this client.
func ListModels(ctx context.Context, cfg Config) ([]string, error) {
	var parsed struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := requestJSON(ctx, cfg, http.MethodGet, "/api/tags", "/models", nil, &parsed, false); err != nil {
		return nil, err
	}
	var out []string
	if cfg.APIStyle == APIOllama {
		for _, m := range parsed.Models {
			out = append(out, m.Name)
		}
	} else {
		for _, m := range parsed.Data {
			out = append(out, m.ID)
		}
	}
	return dedupeNonEmpty(out), nil
}

// ResolveModelName resolves a preference without auto-selecting managed models.
func ResolveModelName(ctx context.Context, cfg Config, preferred string) string {
	preferred = strings.TrimSpace(preferred)
	models, err := ListModels(ctx, cfg)
	if err == nil && len(models) > 0 {
		if picked := PickModel(preferred, models).ModelID; picked != "" {
			return picked
		}
	}
	if preferred != "" {
		return preferred
	}
	if !isManagedModel(cfg.DefaultModel) {
		return firstNonEmpty(cfg.DefaultModel, "qwen2")
	}
	return "qwen2"
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v = strings.TrimSpace(v); v != "" {
			return v
		}
	}
	return ""
}

// Chat performs non-streaming completion. Explicit models are not privacy-filtered.
func Chat(ctx context.Context, cfg Config, model string, messages []Message, opts ChatOptions) (string, error) {
	model = firstNonEmpty(model, cfg.DefaultModel, "qwen2")
	if cfg.APIStyle == APIOllama {
		var parsed ollamaChatResponse
		if err := requestJSON(ctx, cfg, http.MethodPost, "/api/chat", "", newOllamaChatRequest(model, messages, opts, false), &parsed, false); err != nil {
			return "", err
		}
		if !parsed.Done {
			return "", upstreamError("incomplete inference response", 200, false)
		}
		return strings.TrimSpace(parsed.Message.Content), nil
	}
	if usesResponsesAPI(model) {
		return postResponsesChat(ctx, NewHTTPClient(cfg.Timeout), cfg, model, messages, opts)
	}
	var parsed struct {
		Choices []struct {
			Message Message `json:"message"`
		} `json:"choices"`
	}
	if err := requestJSON(ctx, cfg, http.MethodPost, "", "/chat/completions", newOpenAIChatRequest(model, messages, opts, false), &parsed, false); err != nil {
		return "", err
	}
	if len(parsed.Choices) == 0 {
		return "", upstreamError("inference chat empty choices", 200, false)
	}
	return strings.TrimSpace(parsed.Choices[0].Message.Content), nil
}

func usesResponsesAPI(model string) bool {
	model = strings.ToLower(strings.TrimSpace(model))
	return strings.HasPrefix(model, "gpt-") || strings.Contains(model, "codex")
}

func newOpenAIChatRequest(model string, messages []Message, opts ChatOptions, stream bool) map[string]any {
	body := map[string]any{"model": model, "messages": messages, "stream": stream}
	if opts.Temperature > 0 {
		body["temperature"] = opts.Temperature
	}
	if opts.TopP > 0 {
		body["top_p"] = opts.TopP
	}
	if opts.MaxTokens > 0 {
		body["max_tokens"] = opts.MaxTokens
	}
	if opts.RepeatPenalty > 0 {
		body["repeat_penalty"] = opts.RepeatPenalty
	}
	if specs := openAITools(opts.Tools); len(specs) > 0 {
		body["tools"] = specs
		body["tool_choice"] = "auto"
	}
	return body
}

func openAITools(tools []Tool) []map[string]any {
	if len(tools) == 0 {
		return nil
	}
	out := make([]map[string]any, 0, len(tools))
	for _, tool := range tools {
		name := strings.TrimSpace(tool.Name)
		if name == "" {
			continue
		}
		params := tool.Parameters
		if params == nil {
			params = map[string]any{"type": "object", "properties": map[string]any{}}
		}
		out = append(out, map[string]any{
			"type": "function",
			"function": map[string]any{
				"name":        name,
				"description": tool.Description,
				"parameters":  params,
			},
		})
	}
	return out
}

// Complete runs one non-streaming chat completion and keeps tool calls.
func Complete(ctx context.Context, cfg Config, model string, messages []Message, opts ChatOptions) (Message, error) {
	model = firstNonEmpty(model, cfg.DefaultModel, "qwen2")
	if usesResponsesAPI(model) {
		return Message{}, upstreamError("inference tools unsupported", 0, false)
	}
	if cfg.APIStyle == APIOllama {
		return completeOllama(ctx, cfg, model, messages, opts)
	}
	var parsed struct {
		Choices []struct {
			Message struct {
				Role      string `json:"role"`
				Content   string `json:"content"`
				ToolCalls []struct {
					ID       string `json:"id"`
					Type     string `json:"type"`
					Function struct {
						Name      string          `json:"name"`
						Arguments json.RawMessage `json:"arguments"`
					} `json:"function"`
				} `json:"tool_calls"`
			} `json:"message"`
		} `json:"choices"`
	}
	body := newOpenAIChatRequest(model, messages, opts, false)
	if err := requestJSON(ctx, cfg, http.MethodPost, "", "/chat/completions", body, &parsed, false); err != nil {
		return Message{}, err
	}
	if len(parsed.Choices) == 0 {
		return Message{}, upstreamError("inference chat empty choices", 200, false)
	}
	msg := parsed.Choices[0].Message
	out := Message{Role: firstNonEmpty(msg.Role, "assistant"), Content: strings.TrimSpace(msg.Content)}
	for i, call := range msg.ToolCalls {
		name := strings.TrimSpace(call.Function.Name)
		if name == "" {
			continue
		}
		id := strings.TrimSpace(call.ID)
		if id == "" {
			id = fmt.Sprintf("call_%d", i+1)
		}
		out.ToolCalls = append(out.ToolCalls, ToolCall{
			ID:   id,
			Type: firstNonEmpty(call.Type, "function"),
			Function: ToolCallFunction{
				Name:      name,
				Arguments: toolArgumentsString(call.Function.Arguments),
			},
		})
	}
	if out.Content == "" && len(out.ToolCalls) == 0 {
		return Message{}, upstreamError("inference chat empty", 200, false)
	}
	return out, nil
}

func toolArgumentsString(raw json.RawMessage) string {
	text := strings.TrimSpace(string(raw))
	if text == "" || text == "null" {
		return "{}"
	}
	if strings.HasPrefix(text, "\"") {
		var decoded string
		if err := json.Unmarshal(raw, &decoded); err == nil {
			return decoded
		}
	}
	return text
}

type ollamaOptions struct {
	Temperature   float64 `json:"temperature"`
	TopP          float64 `json:"top_p,omitempty"`
	NumPredict    int     `json:"num_predict,omitempty"`
	RepeatPenalty float64 `json:"repeat_penalty,omitempty"`
}

type ollamaChatRequest struct {
	Model    string           `json:"model"`
	Messages []ollamaMessage  `json:"messages"`
	Tools    []map[string]any `json:"tools,omitempty"`
	Stream   bool             `json:"stream"`
	Think    bool             `json:"think"`
	Options  ollamaOptions    `json:"options"`
}

// ollamaMessage 把工具参数按对象发给 Ollama。OpenAI 那条链路仍用字符串参数。
type ollamaMessage struct {
	Role      string               `json:"role"`
	Content   string               `json:"content,omitempty"`
	ToolName  string               `json:"tool_name,omitempty"`
	ToolCalls []ollamaToolCallBody `json:"tool_calls,omitempty"`
}

type ollamaToolCallBody struct {
	ID       string `json:"id,omitempty"`
	Type     string `json:"type,omitempty"`
	Function struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	} `json:"function"`
}

func newOllamaChatRequest(model string, messages []Message, opts ChatOptions, stream bool) ollamaChatRequest {
	return ollamaChatRequest{
		Model:    model,
		Messages: ollamaMessages(messages),
		Tools:    openAITools(opts.Tools),
		Stream:   stream,
		Think:    false,
		Options:  ollamaOptions{Temperature: opts.Temperature, TopP: opts.TopP, NumPredict: opts.MaxTokens, RepeatPenalty: opts.RepeatPenalty},
	}
}

func ollamaMessages(messages []Message) []ollamaMessage {
	names := map[string]string{}
	out := make([]ollamaMessage, 0, len(messages))
	for _, msg := range messages {
		item := ollamaMessage{Role: msg.Role, Content: msg.Content}
		for _, call := range msg.ToolCalls {
			names[call.ID] = call.Function.Name
			body := ollamaToolCallBody{ID: call.ID, Type: firstNonEmpty(call.Type, "function")}
			body.Function.Name = call.Function.Name
			body.Function.Arguments = ollamaArguments(call.Function.Arguments)
			item.ToolCalls = append(item.ToolCalls, body)
		}
		if msg.Role == "tool" {
			item.ToolName = names[msg.ToolCallID]
		}
		out = append(out, item)
	}
	return out
}

func ollamaArguments(raw string) json.RawMessage {
	text := strings.TrimSpace(raw)
	if text == "" {
		return json.RawMessage("{}")
	}
	if json.Valid([]byte(text)) && (strings.HasPrefix(text, "{") || strings.HasPrefix(text, "[")) {
		return json.RawMessage(text)
	}
	encoded, err := json.Marshal(text)
	if err != nil {
		return json.RawMessage("{}")
	}
	return encoded
}

func completeOllama(ctx context.Context, cfg Config, model string, messages []Message, opts ChatOptions) (Message, error) {
	var parsed struct {
		Message struct {
			Role      string `json:"role"`
			Content   string `json:"content"`
			ToolCalls []struct {
				ID       string `json:"id"`
				Type     string `json:"type"`
				Function struct {
					Name      string          `json:"name"`
					Arguments json.RawMessage `json:"arguments"`
				} `json:"function"`
			} `json:"tool_calls"`
		} `json:"message"`
		Done bool `json:"done"`
	}
	if err := requestJSON(ctx, cfg, http.MethodPost, "/api/chat", "", newOllamaChatRequest(model, messages, opts, false), &parsed, false); err != nil {
		return Message{}, err
	}
	if !parsed.Done {
		return Message{}, upstreamError("incomplete inference response", 200, false)
	}
	out := Message{Role: firstNonEmpty(parsed.Message.Role, "assistant"), Content: strings.TrimSpace(parsed.Message.Content)}
	for i, call := range parsed.Message.ToolCalls {
		name := strings.TrimSpace(call.Function.Name)
		if name == "" {
			continue
		}
		id := strings.TrimSpace(call.ID)
		if id == "" {
			id = fmt.Sprintf("call_%d", i+1)
		}
		out.ToolCalls = append(out.ToolCalls, ToolCall{
			ID:   id,
			Type: firstNonEmpty(call.Type, "function"),
			Function: ToolCallFunction{
				Name:      name,
				Arguments: toolArgumentsString(call.Function.Arguments),
			},
		})
	}
	if out.Content == "" && len(out.ToolCalls) == 0 {
		return Message{}, upstreamError("inference chat empty", 200, false)
	}
	return out, nil
}

type ollamaChatResponse struct {
	Message Message `json:"message"`
	Done    bool    `json:"done"`
}
