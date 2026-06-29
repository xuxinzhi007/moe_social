package llmbiz

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"

	"backend/pkg/llminference"
)

type ConfigSnapshot struct {
	InferenceBaseURL       string
	InferenceAPIStyle      string
	InferenceTimeoutSec    int
	MemoryModel            string
	HasSummaryPrompt       bool
	HasExtractPrompt       bool
	LocalModelsStorageDir  string
	LocalModelsCatalogSize int
	MemoryBudget           MemoryBudgetConfig
}

type MemoryBudgetConfig struct {
	MaxCtxTokens      int
	CtxSafeRatio      float64
	MaxHistoryMessages int
	KeepRecentMessages int
}

func DefaultMemoryBudget() MemoryBudgetConfig {
	return MemoryBudgetConfig{
		MaxCtxTokens:       8192,
		CtxSafeRatio:       0.75,
		MaxHistoryMessages: 40,
		KeepRecentMessages: 12,
	}
}

func ConfigAPIPayload(cfg ConfigSnapshot) map[string]interface{} {
	return map[string]interface{}{
		"inference_base_url":    cfg.InferenceBaseURL,
		"inference_api_style":   cfg.InferenceAPIStyle,
		"inference_timeout_sec": cfg.InferenceTimeoutSec,
		"memory_model":          cfg.MemoryModel,
		"has_summary_prompt":    cfg.HasSummaryPrompt,
		"has_extract_prompt":    cfg.HasExtractPrompt,
		"memory_budget": map[string]interface{}{
			"max_ctx_tokens":       cfg.MemoryBudget.MaxCtxTokens,
			"ctx_safe_ratio":       cfg.MemoryBudget.CtxSafeRatio,
			"max_history_messages": cfg.MemoryBudget.MaxHistoryMessages,
			"keep_recent_messages": cfg.MemoryBudget.KeepRecentMessages,
		},
	}
}

type PlatformWriteResult struct {
	Code    int
	Message string
	Success bool
}

type CreateAgentInput struct {
	Name         string
	BaseModel    string
	SystemPrompt string
}

type ModelCacheClearer interface {
	Clear()
}

func ForwardChatRaw(w http.ResponseWriter, r *http.Request, cfg llminference.Config) error {
	if !cfg.Ready() {
		return fmt.Errorf("inference config unavailable")
	}
	baseURL := strings.TrimRight(cfg.BaseURL, "/")
	targetURL := baseURL + "/v1/chat/completions"
	return proxyRequest(w, r, targetURL, cfg.Timeout)
}

func ForwardModelsRaw(w http.ResponseWriter, r *http.Request, cfg llminference.Config) error {
	if !cfg.Ready() {
		return fmt.Errorf("inference config unavailable")
	}
	baseURL := strings.TrimRight(cfg.BaseURL, "/")
	targetURL := baseURL + "/v1/models"
	return proxyRequest(w, r, targetURL, cfg.Timeout)
}

func ForwardShowRaw(w http.ResponseWriter, r *http.Request, cfg llminference.Config) error {
	if !cfg.Ready() {
		return fmt.Errorf("inference config unavailable")
	}
	baseURL := strings.TrimRight(cfg.BaseURL, "/")
	targetURL := baseURL + "/v1/models/"
	return proxyRequest(w, r, targetURL, cfg.Timeout)
}

func proxyRequest(w http.ResponseWriter, r *http.Request, targetURL string, timeout interface{}) error {
	client := &http.Client{}
	req, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL, r.Body)
	if err != nil {
		return err
	}
	for k, v := range r.Header {
		if strings.EqualFold(k, "Host") || strings.EqualFold(k, "Content-Length") {
			continue
		}
		req.Header[k] = v
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	for k, v := range resp.Header {
		w.Header()[k] = v
	}
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
	return nil
}

func CreateOllamaAgent(ctx context.Context, cfg llminference.Config, in CreateAgentInput, cache ModelCacheClearer) PlatformWriteResult {
	return PlatformWriteResult{
		Code:    501,
		Message: "未实现",
		Success: false,
	}
}

func DeleteOllamaModel(ctx context.Context, cfg llminference.Config, model string, cache ModelCacheClearer) PlatformWriteResult {
	return PlatformWriteResult{
		Code:    501,
		Message: "未实现",
		Success: false,
	}
}

func DownloadOllamaModel(ctx context.Context, cfg llminference.Config, model string, cache ModelCacheClearer) PlatformWriteResult {
	return PlatformWriteResult{
		Code:    501,
		Message: "未实现",
		Success: false,
	}
}
