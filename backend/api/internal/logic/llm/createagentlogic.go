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

func NewCreateAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateAgentLogic {
	return &CreateAgentLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateAgentLogic) CreateAgent(req *types.LlmCreateAgentReq) (*types.BaseResp, error) {
	name := strings.TrimSpace(req.Name)
	baseModel := strings.TrimSpace(req.BaseModel)
	systemPrompt := strings.TrimSpace(req.SystemPrompt)

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

	escapedPrompt := strings.ReplaceAll(systemPrompt, `"`, `\"`)
	modelfile := fmt.Sprintf("FROM %s\n\nSYSTEM \"%s\"\n", baseModel, escapedPrompt)

	body := map[string]interface{}{
		"name":      safeName,
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

	baseURL := strings.TrimRight(l.svcCtx.Config.Ollama.BaseUrl, "/")
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
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := client.Do(httpReq)
	if err != nil {
		resp := common.HandleError(err)
		return &resp, nil
	}
	defer httpResp.Body.Close()

	respBody, _ := io.ReadAll(httpResp.Body)

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		err = fmt.Errorf("创建 Ollama 模型失败: %s", strings.TrimSpace(string(respBody)))
		resp := common.HandleError(err)
		return &resp, nil
	}

	var apiResp map[string]interface{}
	_ = json.Unmarshal(respBody, &apiResp)

	resp := common.HandleError(nil)
	resp.Message = "模型创建成功"
	return &resp, nil
}

