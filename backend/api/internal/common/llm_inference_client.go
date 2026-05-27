package common

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"backend/api/internal/config"
)

// InferenceAPIStyle 推理服务 API 风格（当前仅 OpenAI 兼容，如 llama-server）。
type InferenceAPIStyle string

const InferenceAPIOpenAI InferenceAPIStyle = "openai"

// InferenceConfig 后端 /api/llm/* 转发目标。
type InferenceConfig struct {
	BaseURL        string
	ApiStyle       InferenceAPIStyle
	TimeoutSeconds int
}

// ChatMessage OpenAI 兼容消息体。
type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatOptions 可选采样参数。
type ChatOptions struct {
	Temperature   float64
	TopP          float64
	MaxTokens     int
	RepeatPenalty float64
}

// InferenceFromLLMConf 从 go-zero 配置构建推理客户端。
func InferenceFromLLMConf(c config.LLMInferenceConf) (InferenceConfig, error) {
	base, err := ResolveInferenceBaseURL(c.BaseUrl)
	if err != nil {
		return InferenceConfig{}, err
	}
	timeout := c.TimeoutSeconds
	if timeout <= 0 {
		timeout = 60
	}
	return InferenceConfig{
		BaseURL:        base,
		ApiStyle:       ResolveInferenceAPIStyle(c.ApiStyle, base),
		TimeoutSeconds: timeout,
	}, nil
}

// ResolveInferenceBaseURL 解析推理服务根地址（llama-server / llama.cpp）。
func ResolveInferenceBaseURL(configured string) (string, error) {
	baseURL := strings.TrimRight(strings.TrimSpace(configured), "/")
	if baseURL == "" {
		return "", fmt.Errorf("llm inference base url is empty, set llm_inference.base_url in config")
	}
	return baseURL, nil
}

// ResolveInferenceAPIStyle 决定 API 风格；未配置或非 openai 别名时统一为 OpenAI 兼容。
func ResolveInferenceAPIStyle(configured, baseURL string) InferenceAPIStyle {
	_ = baseURL
	switch strings.ToLower(strings.TrimSpace(configured)) {
	case "openai", "openai_compatible", "llama_cpp", "llamacpp", "":
		return InferenceAPIOpenAI
	default:
		return InferenceAPIOpenAI
	}
}

// PostChatCompletion 非流式对话补全。
func PostChatCompletion(
	ctx context.Context,
	client *http.Client,
	cfg InferenceConfig,
	model string,
	messages []ChatMessage,
	opts ChatOptions,
) (content string, err error) {
	return postOpenAIChat(ctx, client, cfg.BaseURL, model, messages, opts)
}

// ListModelNames 拉取可用模型 ID 列表（OpenAI 兼容 /v1/models）。
func ListModelNames(ctx context.Context, client *http.Client, cfg InferenceConfig) ([]string, error) {
	return listOpenAIModels(ctx, client, cfg.BaseURL)
}

func postOpenAIChat(
	ctx context.Context,
	client *http.Client,
	baseURL, model string,
	messages []ChatMessage,
	opts ChatOptions,
) (string, error) {
	root := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	apiRoot := root
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
	ApplyInferenceForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json")

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

func listOpenAIModels(ctx context.Context, client *http.Client, baseURL string) ([]string, error) {
	root := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	apiRoot := root
	if !strings.HasSuffix(apiRoot, "/v1") {
		apiRoot += "/v1"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiRoot+"/models", nil)
	if err != nil {
		return nil, err
	}
	ApplyInferenceForwardHeaders(req)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("list models failed: %d %s", resp.StatusCode, string(b))
	}
	var parsed struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(parsed.Data))
	for _, m := range parsed.Data {
		if id := strings.TrimSpace(m.ID); id != "" {
			out = append(out, id)
		}
	}
	return out, nil
}

// InferenceChatPath 返回 raw 转发用的路径（含前导 /）。
func InferenceChatPath(style InferenceAPIStyle) string {
	_ = style
	return "/v1/chat/completions"
}
