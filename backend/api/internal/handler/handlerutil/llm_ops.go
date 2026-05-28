package handlerutil

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

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"
)

// LLMListModels returns cached or freshly fetched model names.
func LLMListModels(ctx context.Context, svcCtx *svc.ServiceContext) (*types.LlmModelsResp, error) {
	if models, found := svcCtx.ModelCache.Get(); found {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(nil),
			Models:   models,
		}, nil
	}

	var names []string
	var err error
	if svcCtx.LLMApp != nil {
		names, err = svcCtx.LLMApp.ListModels(ctx)
	} else {
		cfg, cfgErr := common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
		if cfgErr != nil {
			return &types.LlmModelsResp{
				BaseResp: common.HandleError(cfgErr),
				Models:   nil,
			}, nil
		}
		reqCtx, cancel := context.WithTimeout(ctx, time.Duration(cfg.TimeoutSeconds)*time.Second)
		defer cancel()
		client := utils.NewHTTPClient(cfg.TimeoutSeconds)
		names, err = common.ListModelNames(reqCtx, client, cfg)
	}
	if err != nil {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(err),
			Models:   nil,
		}, nil
	}

	svcCtx.ModelCache.Set(names)

	return &types.LlmModelsResp{
		BaseResp: common.HandleError(nil),
		Models:   names,
	}, nil
}

// LLMModelsRaw proxies GET /api/tags to the inference backend.
func LLMModelsRaw(ctx context.Context, svcCtx *svc.ServiceContext, w http.ResponseWriter, r *http.Request) error {
	timeoutSeconds := svcCtx.Config.LLMInference.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 10
	}

	baseURL, err := common.ResolveInferenceBaseURL(svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, baseURL+"/api/tags", nil)
	if err != nil {
		return err
	}
	common.ApplyInferenceForwardHeaders(req)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(resp.Body)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(raw)
	return nil
}

// LLMShowRaw proxies POST /api/show to the inference backend.
func LLMShowRaw(ctx context.Context, svcCtx *svc.ServiceContext, w http.ResponseWriter, r *http.Request) error {
	timeoutSeconds := svcCtx.Config.LLMInference.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 15
	}

	baseURL, err := common.ResolveInferenceBaseURL(svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		return err
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
	req, err := http.NewRequestWithContext(
		r.Context(), http.MethodPost,
		baseURL+"/api/show",
		strings.NewReader(string(body)),
	)
	if err != nil {
		return err
	}
	common.ApplyInferenceForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(resp.Body)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(raw)
	return nil
}

// LLMChatRaw forwards the request body to the local inference chat endpoint.
func LLMChatRaw(ctx context.Context, svcCtx *svc.ServiceContext, w http.ResponseWriter, r *http.Request) error {
	cfg, err := common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
	if err != nil {
		return err
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}

	target := strings.TrimRight(cfg.BaseURL, "/") + common.InferenceChatPath(cfg.ApiStyle)
	client := &http.Client{Timeout: 0}
	req, err := http.NewRequestWithContext(
		r.Context(), http.MethodPost, target, strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	common.ApplyInferenceForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if ct := resp.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	} else {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
	}
	w.WriteHeader(resp.StatusCode)

	flusher, _ := w.(http.Flusher)
	buf := make([]byte, 16*1024)
	for {
		n, readErr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				return nil
			}
			if flusher != nil {
				flusher.Flush()
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return readErr
		}
	}
	return nil
}

// LLMDeleteModel deletes a model from Ollama.
func LLMDeleteModel(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmDeleteModelReq) (*types.BaseResp, error) {
	if req.Model == "" {
		resp := common.HandleError(fmt.Errorf("模型名称不能为空"))
		return &resp, nil
	}

	timeoutSeconds := svcCtx.Config.LLMInference.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 60
	}

	baseUrl, err := common.ResolveInferenceBaseURL(svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	client := utils.NewHTTPClient(timeoutSeconds)

	body, err := json.Marshal(map[string]string{
		"name": req.Model,
	})
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	reqCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(reqCtx, http.MethodDelete, baseUrl+"/api/delete", bytes.NewReader(body))
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	common.ApplyInferenceForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	var httpResp *http.Response
	var retryErr error
	for i := 0; i <= utils.DefaultRetryConfig.MaxRetries; i++ {
		httpResp, retryErr = client.Do(httpReq)
		if retryErr == nil && httpResp.StatusCode == http.StatusOK {
			break
		}
		if retryErr == nil && !utils.IsRetryableStatus(httpResp.StatusCode) {
			break
		}
		if i < utils.DefaultRetryConfig.MaxRetries {
			delay := time.Duration(float64(utils.DefaultRetryConfig.InitialDelay) * (utils.DefaultRetryConfig.BackoffFactor * float64(i)))
			if delay > utils.DefaultRetryConfig.MaxDelay {
				delay = utils.DefaultRetryConfig.MaxDelay
			}
			time.Sleep(delay)
		}
	}

	if retryErr != nil {
		resp := common.HandleError(retryErr)
		return &resp, nil
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		resp := common.HandleError(fmt.Errorf("删除模型失败: %d %s", httpResp.StatusCode, string(raw)))
		return &resp, nil
	}

	svcCtx.ModelCache.Clear()

	respValue := common.HandleError(nil)
	respValue.Message = "模型删除成功"
	return &respValue, nil
}

// LLMDownloadModel pulls a model from Ollama.
func LLMDownloadModel(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmDownloadModelReq) (*types.BaseResp, error) {
	if req.Model == "" {
		resp := common.HandleError(fmt.Errorf("模型名称不能为空"))
		return &resp, nil
	}

	timeoutSeconds := svcCtx.Config.LLMInference.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 300
	}

	baseUrl, err := common.ResolveInferenceBaseURL(svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	client := utils.NewHTTPClient(timeoutSeconds)

	body, err := json.Marshal(map[string]string{
		"name": req.Model,
	})
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	reqCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(reqCtx, http.MethodPost, baseUrl+"/api/pull", bytes.NewReader(body))
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	common.ApplyInferenceForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	var httpResp *http.Response
	var retryErr error
	for i := 0; i <= utils.DefaultRetryConfig.MaxRetries; i++ {
		httpResp, retryErr = client.Do(httpReq)
		if retryErr == nil && (httpResp.StatusCode == http.StatusOK || httpResp.StatusCode == http.StatusAccepted) {
			break
		}
		if retryErr == nil && !utils.IsRetryableStatus(httpResp.StatusCode) {
			break
		}
		if i < utils.DefaultRetryConfig.MaxRetries {
			delay := time.Duration(float64(utils.DefaultRetryConfig.InitialDelay) * (utils.DefaultRetryConfig.BackoffFactor * float64(i)))
			if delay > utils.DefaultRetryConfig.MaxDelay {
				delay = utils.DefaultRetryConfig.MaxDelay
			}
			time.Sleep(delay)
		}
	}

	if retryErr != nil {
		resp := common.HandleError(retryErr)
		return &resp, nil
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK && httpResp.StatusCode != http.StatusAccepted {
		raw, _ := io.ReadAll(httpResp.Body)
		resp := common.HandleError(fmt.Errorf("下载模型失败: %d %s", httpResp.StatusCode, string(raw)))
		return &resp, nil
	}

	reader := httpResp.Body
	decoder := json.NewDecoder(reader)

	for {
		var chunk map[string]interface{}
		if err := decoder.Decode(&chunk); err != nil {
			if err == io.EOF {
				break
			}
			continue
		}
	}

	svcCtx.ModelCache.Clear()

	respValue := common.HandleError(nil)
	respValue.Message = "模型下载成功"
	return &respValue, nil
}

// LLMLocalModelsCatalog returns the local GGUF catalog.
func LLMLocalModelsCatalog(ctx context.Context, svcCtx *svc.ServiceContext) (*types.LlmLocalModelsCatalogResp, error) {
	var items []types.LlmLocalModelCatalogItem
	if svcCtx.LLMApp != nil {
		catalog, err := svcCtx.LLMApp.LocalCatalog()
		if err != nil {
			return &types.LlmLocalModelsCatalogResp{
				BaseResp: common.HandleError(err),
				Items:    nil,
			}, nil
		}
		items = make([]types.LlmLocalModelCatalogItem, 0, len(catalog))
		for _, item := range catalog {
			items = append(items, types.LlmLocalModelCatalogItem{
				Id:           item.ID,
				Name:         item.Name,
				Filename:     item.Filename,
				SizeBytes:    item.SizeBytes,
				Sha256:       item.Sha256,
				Description:  item.Description,
				ParametersB:  item.ParametersB,
				Recommended:  item.Recommended,
				DownloadPath: item.DownloadPath,
			})
		}
	} else {
		legacy, err := common.LoadLocalModelCatalog(svcCtx.Config.LocalModels)
		if err != nil {
			return &types.LlmLocalModelsCatalogResp{
				BaseResp: common.HandleError(err),
				Items:    nil,
			}, nil
		}
		items = make([]types.LlmLocalModelCatalogItem, 0, len(legacy))
		for _, item := range legacy {
			name := item.Name
			if name == "" {
				name = item.ID
			}
			items = append(items, types.LlmLocalModelCatalogItem{
				Id:           item.ID,
				Name:         name,
				Filename:     item.Filename,
				SizeBytes:    item.SizeBytes,
				Sha256:       item.Sha256,
				Description:  item.Description,
				ParametersB:  item.ParametersB,
				Recommended:  item.Recommended,
				DownloadPath: fmt.Sprintf("/api/llm/local-models/%s/download", item.ID),
			})
		}
	}

	return &types.LlmLocalModelsCatalogResp{
		BaseResp: common.HandleError(nil),
		Items:    items,
	}, nil
}

const llmDefaultSystemPrompt = "你是一个自然、友好的中文助手。回答请具体、口语化、可执行，避免空泛模板化回复。"
const llmBuiltInModelfileTemplate = `FROM {{BASE_MODEL}}

SYSTEM """
{{SYSTEM_PROMPT}}
"""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 8192
`

// LLMCreateAgent creates a derived Ollama model (legacy api_style=ollama only).
func LLMCreateAgent(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmCreateAgentReq) (*types.BaseResp, error) {
	style := strings.ToLower(strings.TrimSpace(svcCtx.Config.LLMInference.ApiStyle))
	if style != "ollama" {
		return &types.BaseResp{
			Code:    400,
			Message: "创建派生模型仅适用于遗留 Ollama；当前推理为 llama-server（openai），请使用角色卡 system 提示词",
			Success: false,
		}, nil
	}
	name := strings.TrimSpace(req.Name)
	baseModel := strings.TrimSpace(req.BaseModel)
	systemPrompt := strings.TrimSpace(req.SystemPrompt)
	if systemPrompt == "" {
		systemPrompt = llmDefaultSystemPrompt
	}

	if name == "" || baseModel == "" {
		resp := common.HandleError(fmt.Errorf("模型名称和基础模型不能为空"))
		return &resp, nil
	}

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

	if safeName == "" {
		resp := common.HandleError(fmt.Errorf("无效的模型名称"))
		return &resp, nil
	}

	modelfile := llmRenderBuiltInModelfile(baseModel, systemPrompt)

	body := map[string]interface{}{
		"model":     safeName,
		"modelfile": modelfile,
		"stream":    false,
	}

	payload, err := json.Marshal(body)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	client := &http.Client{
		Timeout: 10 * time.Minute,
	}

	baseURL, err := common.ResolveInferenceBaseURL(svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	createURL, err := url.JoinPath(baseURL, "/api/create")
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, createURL, bytes.NewReader(payload))
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	common.ApplyInferenceForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := client.Do(httpReq)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
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
			fallback := map[string]interface{}{
				"model":  safeName,
				"from":   baseModel,
				"system": systemPrompt,
				"stream": false,
			}
			fallbackPayload, merr := json.Marshal(fallback)
			if merr == nil {
				fallbackReq, nerr := http.NewRequestWithContext(ctx, http.MethodPost, createURL, bytes.NewReader(fallbackPayload))
				if nerr == nil {
					common.ApplyInferenceForwardHeaders(fallbackReq)
					fallbackReq.Header.Set("Content-Type", "application/json")
					fallbackResp, derr := client.Do(fallbackReq)
					if derr == nil {
						defer fallbackResp.Body.Close()
						fallbackBody, _ := io.ReadAll(fallbackResp.Body)
						if fallbackResp.StatusCode >= 200 && fallbackResp.StatusCode < 300 {
							resp := common.HandleError(nil)
							resp.Message = "模型创建成功"
							return &resp, nil
						}
						rawErr = strings.TrimSpace(string(fallbackBody))
					}
				}
			}
		}
		err = fmt.Errorf("创建 Ollama 模型失败(%d): %s", httpResp.StatusCode, rawErr)
		resp := common.HandleError(err)
		return &resp, nil
	}

	svcCtx.ModelCache.Clear()

	resp := common.HandleError(nil)
	resp.Message = "模型创建成功"
	return &resp, nil
}

func llmRenderBuiltInModelfile(baseModel, systemPrompt string) string {
	out := strings.ReplaceAll(llmBuiltInModelfileTemplate, "{{BASE_MODEL}}", baseModel)
	out = strings.ReplaceAll(out, "{{SYSTEM_PROMPT}}", systemPrompt)
	return out
}
