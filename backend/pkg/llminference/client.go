// Package llminference 提供与具体 API 层解耦的本地推理客户端（OpenAI 兼容 / 遗留 Ollama）。
package llminference

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// APIStyle 推理服务 API 风格。
type APIStyle string

const (
	APIOpenAI APIStyle = "openai"
	APIOllama APIStyle = "ollama"
)

// Config 推理端点配置。
type Config struct {
	BaseURL      string
	APIStyle     APIStyle
	Timeout      time.Duration
	DefaultModel string
	APIKey       string
}

// Message 对话消息。
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatOptions 采样参数。
type ChatOptions struct {
	Temperature float64
	TopP        float64
	MaxTokens   int
}

// ConfigFrom 从统一配置字段构建客户端配置。
func ConfigFrom(baseURL, apiStyle string, timeoutSec int, defaultModel string, apiKey string) Config {
	style := ResolveAPIStyle(apiStyle, baseURL)
	timeout := time.Duration(timeoutSec) * time.Second
	if timeout <= 0 {
		timeout = 120 * time.Second
	}
	return Config{
		BaseURL:      strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		APIStyle:     style,
		Timeout:      timeout,
		DefaultModel: strings.TrimSpace(defaultModel),
		APIKey:       strings.TrimSpace(apiKey),
	}
}

// ResolveAPIStyle 决定 API 风格。
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

// Ready 是否已配置可调用推理服务。
func (c Config) Ready() bool {
	return strings.TrimSpace(c.BaseURL) != ""
}

// Ping 探测推理端点是否可达（短超时，用于 UI 在线状态）。
func Ping(ctx context.Context, cfg Config) bool {
	models, err := ListModels(ctx, cfg)
	return err == nil && len(models) > 0
}

// ListModels 列出推理端点可用模型 ID。
func ListModels(ctx context.Context, cfg Config) ([]string, error) {
	if !cfg.Ready() {
		return nil, fmt.Errorf("llm inference base url is empty")
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	client := &http.Client{Timeout: 5 * time.Second}
	if cfg.APIStyle == APIOllama {
		return listOllamaModels(ctx, client, cfg.BaseURL)
	}
	return listOpenAIModels(ctx, client, cfg)
}

// ResolveModelName 将配置模型名解析为端点实际可用的 model id。
func ResolveModelName(ctx context.Context, cfg Config, preferred string) string {
	preferred = strings.TrimSpace(preferred)
	models, err := ListModels(ctx, cfg)
	if err != nil || len(models) == 0 {
		return firstNonEmpty(preferred, cfg.DefaultModel, "qwen2")
	}
	if preferred == "" {
		return models[0]
	}
	for _, id := range models {
		if id == preferred {
			return id
		}
	}
	lowerPreferred := strings.ToLower(preferred)
	for _, id := range models {
		lowerID := strings.ToLower(id)
		if strings.Contains(lowerID, lowerPreferred) || strings.Contains(lowerPreferred, lowerID) {
			return id
		}
	}
	return models[0]
}

func listOpenAIModels(ctx context.Context, client *http.Client, cfg Config) ([]string, error) {
	apiRoot := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if !strings.HasSuffix(apiRoot, "/v1") {
		apiRoot += "/v1"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiRoot+"/models", nil)
	if err != nil {
		return nil, err
	}
	if cfg.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("list models failed: %d %s", resp.StatusCode, string(body))
	}
	var parsed struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(parsed.Data))
	for _, item := range parsed.Data {
		id := strings.TrimSpace(item.ID)
		if id != "" {
			out = append(out, id)
		}
	}
	return out, nil
}

func listOllamaModels(ctx context.Context, client *http.Client, baseURL string) ([]string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(baseURL, "/")+"/api/tags", nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ollama list models failed: %d %s", resp.StatusCode, string(body))
	}
	var parsed struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(parsed.Models))
	for _, item := range parsed.Models {
		name := strings.TrimSpace(item.Name)
		if name != "" {
			out = append(out, name)
		}
	}
	return out, nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

// Chat 非流式对话补全。
func Chat(
	ctx context.Context,
	cfg Config,
	model string,
	messages []Message,
	opts ChatOptions,
) (string, error) {
	if !cfg.Ready() {
		return "", fmt.Errorf("llm inference base url is empty")
	}
	model = strings.TrimSpace(model)
	if model == "" {
		model = cfg.DefaultModel
	}
	if model == "" {
		model = "qwen2"
	}
	client := &http.Client{Timeout: cfg.Timeout}
	if cfg.APIStyle == APIOllama {
		return postOllamaChat(ctx, client, cfg.BaseURL, model, messages, opts)
	}
	if usesResponsesAPI(model) {
		return postResponsesChat(ctx, client, cfg, model, messages, opts)
	}
	return postOpenAIChat(ctx, client, cfg, model, messages, opts)
}

func usesResponsesAPI(model string) bool {
	model = strings.ToLower(strings.TrimSpace(model))
	return strings.HasPrefix(model, "gpt-") || strings.Contains(model, "codex")
}

func postOpenAIChat(
	ctx context.Context,
	client *http.Client,
	cfg Config,
	model string,
	messages []Message,
	opts ChatOptions,
) (string, error) {
	apiRoot := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if !strings.HasSuffix(apiRoot, "/v1") {
		apiRoot += "/v1"
	}
	body := map[string]any{
		"model":    model,
		"messages": messages,
		"stream":   false,
	}
	if opts.Temperature > 0 {
		body["temperature"] = opts.Temperature
	}
	if opts.TopP > 0 {
		body["top_p"] = opts.TopP
	}
	if opts.MaxTokens > 0 {
		body["max_tokens"] = opts.MaxTokens
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(
		ctx, http.MethodPost, apiRoot+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	if cfg.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("inference chat failed: %d %s", resp.StatusCode, string(respBody))
	}
	var parsed struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return "", err
	}
	if len(parsed.Choices) == 0 {
		return "", fmt.Errorf("inference chat empty choices")
	}
	return strings.TrimSpace(parsed.Choices[0].Message.Content), nil
}

type ollamaChatRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Stream      bool      `json:"stream"`
	Temperature float64   `json:"temperature,omitempty"`
	TopP        float64   `json:"top_p,omitempty"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
}

func postOllamaChat(
	ctx context.Context,
	client *http.Client,
	baseURL, model string,
	messages []Message,
	opts ChatOptions,
) (string, error) {
	reqBody := ollamaChatRequest{Model: model, Messages: messages, Stream: false}
	if opts.Temperature > 0 {
		reqBody.Temperature = opts.Temperature
	}
	if opts.TopP > 0 {
		reqBody.TopP = opts.TopP
	}
	if opts.MaxTokens > 0 {
		reqBody.MaxTokens = opts.MaxTokens
	}
	raw, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}
	url := strings.TrimRight(baseURL, "/") + "/api/chat"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("ollama chat failed: %d %s", resp.StatusCode, string(b))
	}
	var oResp struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&oResp); err != nil {
		return "", err
	}
	return strings.TrimSpace(oResp.Message.Content), nil
}
