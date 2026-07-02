package llminference

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// StreamHandler 收到增量文本时回调；返回非 nil error 可中止流。
type StreamHandler func(chunk string) error

// ChatStream 流式对话补全，返回完整拼接文本。
func ChatStream(
	ctx context.Context,
	cfg Config,
	model string,
	messages []Message,
	opts ChatOptions,
	onChunk StreamHandler,
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
		return streamOllamaChat(ctx, client, cfg.BaseURL, model, messages, opts, onChunk)
	}
	return streamOpenAIChat(ctx, client, cfg, model, messages, opts, onChunk)
}

func streamOpenAIChat(
	ctx context.Context,
	client *http.Client,
	cfg Config,
	model string,
	messages []Message,
	opts ChatOptions,
	onChunk StreamHandler,
) (string, error) {
	apiRoot := strings.TrimRight(strings.TrimSpace(cfg.BaseURL), "/")
	if !strings.HasSuffix(apiRoot, "/v1") {
		apiRoot += "/v1"
	}
	body := map[string]any{
		"model":    model,
		"messages": messages,
		"stream":   true,
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
	req.Header.Set("Accept", "text/event-stream")
	if cfg.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("inference stream failed: %d %s", resp.StatusCode, string(b))
	}
	return readOpenAIStream(resp.Body, onChunk)
}

func readOpenAIStream(r io.Reader, onChunk StreamHandler) (string, error) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	var full strings.Builder
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, ":") {
			continue
		}
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		payload := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if payload == "[DONE]" {
			break
		}
		var parsed struct {
			Choices []struct {
				Delta struct {
					Content string `json:"content"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(payload), &parsed); err != nil {
			continue
		}
		if len(parsed.Choices) == 0 {
			continue
		}
		chunk := parsed.Choices[0].Delta.Content
		if chunk == "" {
			continue
		}
		full.WriteString(chunk)
		if onChunk != nil {
			if err := onChunk(chunk); err != nil {
				return full.String(), err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return full.String(), err
	}
	out := strings.TrimSpace(full.String())
	if out == "" {
		return "", fmt.Errorf("inference stream empty")
	}
	return out, nil
}

func streamOllamaChat(
	ctx context.Context,
	client *http.Client,
	baseURL, model string,
	messages []Message,
	opts ChatOptions,
	onChunk StreamHandler,
) (string, error) {
	reqBody := ollamaChatRequest{Model: model, Messages: messages, Stream: true}
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
		return "", fmt.Errorf("ollama stream failed: %d %s", resp.StatusCode, string(b))
	}
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	var full strings.Builder
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var parsed struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
			Done bool `json:"done"`
		}
		if err := json.Unmarshal([]byte(line), &parsed); err != nil {
			continue
		}
		chunk := parsed.Message.Content
		if chunk == "" {
			if parsed.Done {
				break
			}
			continue
		}
		full.WriteString(chunk)
		if onChunk != nil {
			if err := onChunk(chunk); err != nil {
				return full.String(), err
			}
		}
		if parsed.Done {
			break
		}
	}
	if err := scanner.Err(); err != nil {
		return full.String(), err
	}
	out := strings.TrimSpace(full.String())
	if out == "" {
		return "", fmt.Errorf("ollama stream empty")
	}
	return out, nil
}
