package llmhttp

import (
	"context"

	llmv1 "backend/api/llm/v1"
)

// ListLlmModels 返回推理端当前可用的 model id 列表。
// 客户端在非「终端模式」下走这条结构化路由（终端模式走 /api/llm/models/raw 透传）。
func (s *Server) ListLlmModels(ctx context.Context, _ *llmv1.ListLlmModelsReq) (*llmv1.ListLlmModelsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	models, err := app.ListModels(ctx)
	if err != nil {
		return nil, err
	}
	return &llmv1.ListLlmModelsResp{Models: models}, nil
}
