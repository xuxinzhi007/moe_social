package embed

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

// Chain 多提供方链：按优先级尝试，不绑定单一 Ollama 或中转。
type Chain struct {
	providers []ProviderConfig
	client    *http.Client
}

func NewChain(providers []ProviderConfig) *Chain {
	return &Chain{
		providers: providers,
		client:    &http.Client{Timeout: 90 * time.Second},
	}
}

// Embed 返回向量、实际使用的 provider/model。
func (c *Chain) Embed(ctx context.Context, texts []string) ([][]float32, string, string, error) {
	if len(texts) == 0 {
		return nil, "", "", fmt.Errorf("empty texts")
	}
	var lastErr error
	for _, p := range c.providers {
		vecs, err := c.embedOne(ctx, p, texts)
		if err == nil && len(vecs) == len(texts) {
			return vecs, p.Type, p.Model, nil
		}
		lastErr = err
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("no embedding provider configured")
	}
	return nil, "", "", lastErr
}

func (c *Chain) embedOne(ctx context.Context, p ProviderConfig, texts []string) ([][]float32, error) {
	switch strings.ToLower(p.Type) {
	case "ollama":
		return c.embedOllama(ctx, p, texts)
	case "openai_compatible", "openai":
		return c.embedOpenAI(ctx, p, texts)
	default:
		return nil, fmt.Errorf("unknown embed provider type: %s", p.Type)
	}
}

func (c *Chain) embedOllama(ctx context.Context, p ProviderConfig, texts []string) ([][]float32, error) {
	base := strings.TrimRight(strings.TrimSpace(p.BaseURL), "/")
	model := strings.TrimSpace(p.Model)
	if model == "" {
		model = "nomic-embed-text"
	}
	out := make([][]float32, 0, len(texts))
	for _, text := range texts {
		body, _ := json.Marshal(map[string]any{
			"model":  model,
			"prompt": text,
		})
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/api/embeddings", bytes.NewReader(body))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		resp, err := c.client.Do(req)
		if err != nil {
			return nil, err
		}
		raw, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("ollama embed %d: %s", resp.StatusCode, string(raw))
		}
		var parsed struct {
			Embedding []float64 `json:"embedding"`
		}
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return nil, err
		}
		out = append(out, float64To32(parsed.Embedding))
	}
	return out, nil
}

func (c *Chain) embedOpenAI(ctx context.Context, p ProviderConfig, texts []string) ([][]float32, error) {
	base := strings.TrimRight(strings.TrimSpace(p.BaseURL), "/")
	if !strings.HasSuffix(base, "/v1") {
		base += "/v1"
	}
	model := strings.TrimSpace(p.Model)
	if model == "" {
		model = "text-embedding-3-small"
	}
	input := any(texts[0])
	if len(texts) > 1 {
		input = texts
	}
	body, _ := json.Marshal(map[string]any{
		"model": model,
		"input": input,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/embeddings", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(p.APIKey))
	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	raw, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("openai embed %d: %s", resp.StatusCode, string(raw))
	}
	var parsed struct {
		Data []struct {
			Embedding []float64 `json:"embedding"`
			Index     int       `json:"index"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, err
	}
	if len(texts) == 1 {
		if len(parsed.Data) == 0 {
			return nil, fmt.Errorf("empty embedding data")
		}
		return [][]float32{float64To32(parsed.Data[0].Embedding)}, nil
	}
	out := make([][]float32, len(texts))
	for _, d := range parsed.Data {
		if d.Index >= 0 && d.Index < len(out) {
			out[d.Index] = float64To32(d.Embedding)
		}
	}
	return out, nil
}

func float64To32(in []float64) []float32 {
	out := make([]float32, len(in))
	for i, v := range in {
		out[i] = float32(v)
	}
	return out
}
