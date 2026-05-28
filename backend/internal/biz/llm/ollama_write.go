package llmbiz

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"backend/common/errorcode"
	"backend/pkg/llminference"
)

const (
	defaultCreateAgentTimeout = 10 * time.Minute
	defaultDeleteTimeout      = 60 * time.Second
	defaultDownloadTimeout    = 300 * time.Second
)

// ModelCacheClearer 模型列表缓存失效接口。
type ModelCacheClearer interface {
	Clear()
}

// PlatformWriteResult compat 写路径统一响应。
type PlatformWriteResult struct {
	Code    int
	Message string
	Success bool
}

// CreateAgentInput 创建 Ollama 派生模型参数。
type CreateAgentInput struct {
	Name         string
	BaseModel    string
	SystemPrompt string
}

const defaultAgentSystemPrompt = "你是一个自然、友好的中文助手。回答请具体、口语化、可执行，避免空泛模板化回复。"
const builtInModelfileTemplate = `FROM {{BASE_MODEL}}

SYSTEM """
{{SYSTEM_PROMPT}}
"""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 8192
`

// CreateOllamaAgent 在 Ollama 上创建派生模型。
func CreateOllamaAgent(ctx context.Context, cfg llminference.Config, in CreateAgentInput, cache ModelCacheClearer) PlatformWriteResult {
	if cfg.APIStyle != llminference.APIOllama {
		return PlatformWriteResult{
			Code:    400,
			Message: "创建派生模型仅适用于遗留 Ollama；当前推理为 llama-server（openai），请使用角色卡 system 提示词",
			Success: false,
		}
	}
	name := strings.TrimSpace(in.Name)
	baseModel := strings.TrimSpace(in.BaseModel)
	systemPrompt := strings.TrimSpace(in.SystemPrompt)
	if systemPrompt == "" {
		systemPrompt = defaultAgentSystemPrompt
	}
	if name == "" || baseModel == "" {
		return platformWriteErr(fmt.Errorf("模型名称和基础模型不能为空"))
	}

	safeName := sanitizeOllamaModelName(name)
	if safeName == "" {
		return platformWriteErr(fmt.Errorf("无效的模型名称"))
	}

	modelfile := renderBuiltInModelfile(baseModel, systemPrompt)
	body := map[string]any{
		"model":     safeName,
		"modelfile": modelfile,
		"stream":    false,
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return platformWriteErr(err)
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = defaultCreateAgentTimeout
	}
	client := &http.Client{Timeout: timeout}
	createURL, err := joinInferencePath(cfg.BaseURL, "/api/create")
	if err != nil {
		return platformWriteErr(err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, createURL, bytes.NewReader(payload))
	if err != nil {
		return platformWriteErr(err)
	}
	applyInferenceForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := client.Do(httpReq)
	if err != nil {
		return platformWriteErr(err)
	}
	defer httpResp.Body.Close()

	respBody, _ := io.ReadAll(httpResp.Body)
	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		rawErr := strings.TrimSpace(string(respBody))
		lowErr := strings.ToLower(rawErr)
		if strings.Contains(lowErr, "modelfile") ||
			strings.Contains(lowErr, "unknown field") ||
			strings.Contains(lowErr, "invalid character") ||
			strings.Contains(lowErr, "neither 'from' or 'files' was specified") ||
			strings.Contains(lowErr, "from or files") {
			fallback := map[string]any{
				"model":  safeName,
				"from":   baseModel,
				"system": systemPrompt,
				"stream": false,
			}
			fallbackPayload, merr := json.Marshal(fallback)
			if merr == nil {
				fallbackReq, nerr := http.NewRequestWithContext(ctx, http.MethodPost, createURL, bytes.NewReader(fallbackPayload))
				if nerr == nil {
					applyInferenceForwardHeaders(fallbackReq)
					fallbackReq.Header.Set("Content-Type", "application/json")
					fallbackResp, derr := client.Do(fallbackReq)
					if derr == nil {
						defer fallbackResp.Body.Close()
						fallbackBody, _ := io.ReadAll(fallbackResp.Body)
						if fallbackResp.StatusCode >= 200 && fallbackResp.StatusCode < 300 {
							clearModelCache(cache)
							return PlatformWriteResult{Code: errorcode.E_SUCCESS, Message: "模型创建成功", Success: true}
						}
						rawErr = strings.TrimSpace(string(fallbackBody))
					}
				}
			}
		}
		return platformWriteErr(fmt.Errorf("创建 Ollama 模型失败(%d): %s", httpResp.StatusCode, rawErr))
	}

	clearModelCache(cache)
	return PlatformWriteResult{Code: errorcode.E_SUCCESS, Message: "模型创建成功", Success: true}
}

// DeleteOllamaModel 删除 Ollama 模型。
func DeleteOllamaModel(ctx context.Context, cfg llminference.Config, model string, cache ModelCacheClearer) PlatformWriteResult {
	model = strings.TrimSpace(model)
	if model == "" {
		return platformWriteErr(fmt.Errorf("模型名称不能为空"))
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = defaultDeleteTimeout
	}
	deleteURL, err := joinInferencePath(cfg.BaseURL, "/api/delete")
	if err != nil {
		return platformWriteErr(err)
	}

	body, err := json.Marshal(map[string]string{"name": model})
	if err != nil {
		return platformWriteErr(err)
	}

	reqCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(reqCtx, http.MethodDelete, deleteURL, bytes.NewReader(body))
	if err != nil {
		return platformWriteErr(err)
	}
	applyInferenceForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: timeout}
	httpResp, err := client.Do(httpReq)
	if err != nil {
		return platformWriteErr(err)
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		return platformWriteErr(fmt.Errorf("删除模型失败: %d %s", httpResp.StatusCode, string(raw)))
	}

	clearModelCache(cache)
	return PlatformWriteResult{Code: errorcode.E_SUCCESS, Message: "模型删除成功", Success: true}
}

// DownloadOllamaModel 拉取 Ollama 模型。
func DownloadOllamaModel(ctx context.Context, cfg llminference.Config, model string, cache ModelCacheClearer) PlatformWriteResult {
	model = strings.TrimSpace(model)
	if model == "" {
		return platformWriteErr(fmt.Errorf("模型名称不能为空"))
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = defaultDownloadTimeout
	}
	pullURL, err := joinInferencePath(cfg.BaseURL, "/api/pull")
	if err != nil {
		return platformWriteErr(err)
	}

	body, err := json.Marshal(map[string]string{"name": model})
	if err != nil {
		return platformWriteErr(err)
	}

	reqCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(reqCtx, http.MethodPost, pullURL, bytes.NewReader(body))
	if err != nil {
		return platformWriteErr(err)
	}
	applyInferenceForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: timeout}
	httpResp, err := client.Do(httpReq)
	if err != nil {
		return platformWriteErr(err)
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK && httpResp.StatusCode != http.StatusAccepted {
		raw, _ := io.ReadAll(httpResp.Body)
		return platformWriteErr(fmt.Errorf("下载模型失败: %d %s", httpResp.StatusCode, string(raw)))
	}

	decoder := json.NewDecoder(httpResp.Body)
	for {
		var chunk map[string]any
		if err := decoder.Decode(&chunk); err != nil {
			if err == io.EOF {
				break
			}
			continue
		}
	}

	clearModelCache(cache)
	return PlatformWriteResult{Code: errorcode.E_SUCCESS, Message: "模型下载成功", Success: true}
}

func platformWriteErr(err error) PlatformWriteResult {
	if err == nil {
		return PlatformWriteResult{Code: errorcode.E_SUCCESS, Message: "操作成功", Success: true}
	}
	return PlatformWriteResult{Code: errorcode.E_INTERNAL_ERROR, Message: err.Error(), Success: false}
}

func clearModelCache(cache ModelCacheClearer) {
	if cache != nil {
		cache.Clear()
	}
}

func sanitizeOllamaModelName(name string) string {
	safeName := strings.ToLower(name)
	safeName = strings.ReplaceAll(safeName, " ", "-")
	safeName = strings.ReplaceAll(safeName, "：", ":")
	safeName = strings.ReplaceAll(safeName, "。", ".")
	safeName = strings.ReplaceAll(safeName, "，", ",")
	safeName = strings.ReplaceAll(safeName, "！", "!")
	safeName = strings.ReplaceAll(safeName, "？", "?")
	safeName = strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' || r == ':' || r == '/' {
			return r
		}
		return '_'
	}, safeName)
	return safeName
}

func renderBuiltInModelfile(baseModel, systemPrompt string) string {
	out := strings.ReplaceAll(builtInModelfileTemplate, "{{BASE_MODEL}}", baseModel)
	out = strings.ReplaceAll(out, "{{SYSTEM_PROMPT}}", systemPrompt)
	return out
}

func joinInferencePath(baseURL, suffix string) (string, error) {
	base := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if base == "" {
		return "", fmt.Errorf("llm inference base url is empty")
	}
	return url.JoinPath(base, suffix)
}

func applyInferenceForwardHeaders(req *http.Request) {
	if req == nil {
		return
	}
	req.Header.Set("User-Agent", "moe-social/1.0")
}
