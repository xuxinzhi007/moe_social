package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListAiChatSessions(ctx context.Context, in *adminv1.AdminListAiChatSessionsReq) (*adminv1.AdminListAiChatSessionsResp, error) {
	out, err := adminbiz.AdminListAiChatSessions(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListAiChatMessages(ctx context.Context, in *adminv1.AdminListAiChatMessagesReq) (*adminv1.AdminListAiChatMessagesResp, error) {
	out, err := adminbiz.AdminListAiChatMessages(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ExportAiChatMessages(ctx context.Context, in *adminv1.AdminExportAiChatMessagesReq) (*adminv1.AdminExportAiChatMessagesResp, error) {
	out, err := adminbiz.AdminExportAiChatMessages(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
