package llmapp

import (
	"context"

	aibiz "backend/internal/biz/ai"
	"backend/rpc/pb/super"
)

// GetAiUserConfig 用户 AI 配置读。
func (s *AppService) GetAiUserConfig(ctx context.Context, in *super.GetAiUserConfigReq) (*super.GetAiUserConfigResp, error) {
	return aibiz.GetAiUserConfig(ctx, s.db, in)
}

// UpsertAiUserConfig 用户 AI 配置写。
func (s *AppService) UpsertAiUserConfig(ctx context.Context, in *super.UpsertAiUserConfigReq) (*super.UpsertAiUserConfigResp, error) {
	return aibiz.UpsertAiUserConfig(ctx, s.db, in)
}
