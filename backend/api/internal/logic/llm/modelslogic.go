package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type ModelsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewModelsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ModelsLogic {
	return &ModelsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ModelsLogic) Models(req *types.EmptyReq) (resp *types.LlmModelsResp, err error) {
	// 尝试从缓存获取
	if models, found := l.svcCtx.ModelCache.Get(); found {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(nil),
			Models:   models,
		}, nil
	}

	type ollamaModel struct {
		Name string `json:"name"`
	}

	type ollamaResponse struct {
		Models []ollamaModel `json:"models"`
	}

	timeoutSeconds := l.svcCtx.Config.Ollama.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 10
	}

	baseUrl := strings.TrimRight(l.svcCtx.Config.Ollama.BaseUrl, "/")
	if baseUrl == "" {
		baseUrl = "http://127.0.0.1:11434"
	}

	ctx, cancel := context.WithTimeout(l.ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	client := utils.NewHTTPClient(timeoutSeconds)

	url := baseUrl + "/api/tags"

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(err),
			Models:   nil,
		}, nil
	}

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
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(retryErr),
			Models:   nil,
		}, nil
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(fmt.Errorf("获取 Ollama 模型列表失败: %d %s", httpResp.StatusCode, string(raw))),
			Models:   nil,
		}, nil
	}

	var oResp ollamaResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&oResp); err != nil {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(err),
			Models:   nil,
		}, nil
	}

	names := make([]string, 0, len(oResp.Models))
	for _, m := range oResp.Models {
		if m.Name != "" {
			names = append(names, m.Name)
		}
	}

	// 缓存结果
	l.svcCtx.ModelCache.Set(names)

	return &types.LlmModelsResp{
		BaseResp: common.HandleError(nil),
		Models:   names,
	}, nil
}
