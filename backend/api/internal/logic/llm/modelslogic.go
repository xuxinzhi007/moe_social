package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

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
	type ollamaModel struct {
		Name string `json:"name"`
	}

	type ollamaResponse struct {
		Models []ollamaModel `json:"models"`
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	url := "http://127.0.0.1:11434/api/tags"

	httpReq, err := http.NewRequestWithContext(l.ctx, http.MethodGet, url, nil)
	if err != nil {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(err),
			Models:   nil,
		}, nil
	}

	httpResp, err := client.Do(httpReq)
	if err != nil {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(err),
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

	return &types.LlmModelsResp{
		BaseResp: common.HandleError(nil),
		Models:   names,
	}, nil
}
