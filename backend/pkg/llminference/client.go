// Package llminference provides OpenAI-compatible and native Ollama inference clients.
package llminference

import (
	"context"
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

// Message is a chat message.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatOptions contains sampling parameters.
type ChatOptions struct {
	Temperature   float64
	TopP          float64
	MaxTokens     int
	RepeatPenalty float64
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
	return body
}

type ollamaOptions struct {
	Temperature   float64 `json:"temperature"`
	TopP          float64 `json:"top_p,omitempty"`
	NumPredict    int     `json:"num_predict,omitempty"`
	RepeatPenalty float64 `json:"repeat_penalty,omitempty"`
}

type ollamaChatRequest struct {
	Model    string        `json:"model"`
	Messages []Message     `json:"messages"`
	Stream   bool          `json:"stream"`
	Think    bool          `json:"think"`
	Options  ollamaOptions `json:"options"`
}

func newOllamaChatRequest(model string, messages []Message, opts ChatOptions, stream bool) ollamaChatRequest {
	return ollamaChatRequest{Model: model, Messages: messages, Stream: stream, Think: false,
		Options: ollamaOptions{Temperature: opts.Temperature, TopP: opts.TopP, NumPredict: opts.MaxTokens, RepeatPenalty: opts.RepeatPenalty}}
}

type ollamaChatResponse struct {
	Message Message `json:"message"`
	Done    bool    `json:"done"`
}
