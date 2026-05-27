package llm

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

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateAgentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

const defaultSystemPrompt = "你是一个自然、友好的中文助手。回答请具体、口语化、可执行，避免空泛模板化回复。"
const builtInModelfileTemplate = `FROM {{BASE_MODEL}}

SYSTEM """
{{SYSTEM_PROMPT}}
"""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 8192
`

func NewCreateAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateAgentLogic {
	return &CreateAgentLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateAgentLogic) CreateAgent(req *types.LlmCreateAgentReq) (*types.BaseResp, error) {
	style := strings.ToLower(strings.TrimSpace(l.svcCtx.Config.LLMInference.ApiStyle))
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
		systemPrompt = defaultSystemPrompt
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

	modelfile := renderBuiltInModelfile(baseModel, systemPrompt)

	// 首选 modelfile 创建，满足「可控模板 + 默认文件」诉求。
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

	baseURL, err := common.ResolveInferenceBaseURL(l.svcCtx.Config.LLMInference.BaseUrl)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	createURL, err := url.JoinPath(baseURL, "/api/create")
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}

	httpReq, err := http.NewRequestWithContext(l.ctx, http.MethodPost, createURL, bytes.NewReader(payload))
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
		// 兼容部分旧版/定制 Ollama：若不支持 modelfile 字段，则回退 from/system 方式。
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
				fallbackReq, nerr := http.NewRequestWithContext(l.ctx, http.MethodPost, createURL, bytes.NewReader(fallbackPayload))
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

	var apiResp map[string]interface{}
	_ = json.Unmarshal(respBody, &apiResp)

	// 创建成功后主动失效模型缓存，确保前端立即看到最新模型列表。
	l.svcCtx.ModelCache.Clear()

	resp := common.HandleError(nil)
	resp.Message = "模型创建成功"
	return &resp, nil
}

func renderBuiltInModelfile(baseModel, systemPrompt string) string {
	out := strings.ReplaceAll(builtInModelfileTemplate, "{{BASE_MODEL}}", baseModel)
	out = strings.ReplaceAll(out, "{{SYSTEM_PROMPT}}", systemPrompt)
	return out
}
