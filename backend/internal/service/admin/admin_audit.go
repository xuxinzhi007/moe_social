package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListAuditLogs(ctx context.Context, in *adminv1.AdminListAuditLogsReq) (*adminv1.AdminListAuditLogsResp, error) {
	items, total, err := adminbiz.ListAuditLogs(ctx, s.store, adminbiz.AuditLogFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Action: in.GetAction(),
		Resource: in.GetResource(), AdminID: in.GetAdminId(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListAuditLogsV1(items, total), nil
}

// RecordAuditLog 写入管理端操作审计。
func (s *AppService) RecordAuditLog(ctx context.Context, in *adminv1.RecordAdminAuditLogReq) (*adminv1.RecordAdminAuditLogResp, error) {
	if err := adminbiz.RecordAuditLog(ctx, s.store, in); err != nil {
		return nil, err
	}
	return &adminv1.RecordAdminAuditLogResp{}, nil
}
