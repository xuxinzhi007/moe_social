package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListAiAgents(ctx context.Context, in *adminv1.AdminListAiAgentsReq) (*adminv1.AdminListAiAgentsResp, error) {
	out, err := adminbiz.ListAiAgents(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *adminv1.AdminDeleteAiAgentReq) (*adminv1.AdminDeleteAiAgentResp, error) {
	out, err := adminbiz.DeleteAiAgent(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
