package llmapp

import (
	"context"

	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	llmv1 "backend/api/llm/v1"
)

// GetAiUserConfig 用户 AI 配置读。
func (s *AppService) GetAiUserConfig(ctx context.Context, in *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	out, err := aibiz.GetAiUserConfig(ctx, aidata.NewStore(s.db), llmv1.GetAiUserConfigReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.GetAiUserConfigRespFromMoe(out), nil
}

// UpsertAiUserConfig 用户 AI 配置写。
func (s *AppService) UpsertAiUserConfig(ctx context.Context, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	out, err := aibiz.UpsertAiUserConfig(ctx, aidata.NewStore(s.db), llmv1.UpsertAiUserConfigReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.UpsertAiUserConfigRespFromMoe(out), nil
}
