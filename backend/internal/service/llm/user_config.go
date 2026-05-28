package llmapp

import (
	"context"

	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	"backend/rpc/pb/moe"
)

// GetAiUserConfig 用户 AI 配置读。
func (s *AppService) GetAiUserConfig(ctx context.Context, in *moe.GetAiUserConfigReq) (*moe.GetAiUserConfigResp, error) {
	return aibiz.GetAiUserConfig(ctx, aidata.NewStore(s.db), in)
}

// UpsertAiUserConfig 用户 AI 配置写。
func (s *AppService) UpsertAiUserConfig(ctx context.Context, in *moe.UpsertAiUserConfigReq) (*moe.UpsertAiUserConfigResp, error) {
	return aibiz.UpsertAiUserConfig(ctx, aidata.NewStore(s.db), in)
}
