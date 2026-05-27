package logic

import (
	"context"
	"errors"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAuditLogsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAuditLogsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAuditLogsLogic {
	return &AdminListAuditLogsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAuditLogsLogic) AdminListAuditLogs(in *super.AdminListAuditLogsReq) (*super.AdminListAuditLogsResp, error) {
	items, total, err := adminbiz.ListAuditLogs(l.ctx, l.svcCtx.DB, adminbiz.AuditLogFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Action: in.GetAction(),
		Resource: in.GetResource(), AdminID: in.GetAdminId(),
	})
	if err != nil {
		if errors.Is(err, adminbiz.ErrInvalidArgument) {
			return nil, errorx.InvalidArgument("管理员 ID 无效")
		}
		l.Errorf("[admin] list audit logs: %v", err)
		return nil, errorx.Internal("查询审计日志失败")
	}
	return &super.AdminListAuditLogsResp{Items: items, Total: total}, nil
}
