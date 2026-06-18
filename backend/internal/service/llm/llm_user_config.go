package llmapp

import (
	"context"
	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	llmv1 "backend/api/llm/v1"
)

// GetAiUserConfig 用户 AI 配置读。
func (s *AppService) GetAiUserConfig(ctx context.Context, in *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	return aibiz.GetAiUserConfig(ctx, aidata.NewStore(s.db), in)
}

// UpsertAiUserConfig 用户 AI 配置写。
func (s *AppService) UpsertAiUserConfig(ctx context.Context, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	return aibiz.UpsertAiUserConfig(ctx, aidata.NewStore(s.db), in)
}
