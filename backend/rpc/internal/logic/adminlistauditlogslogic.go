package logic

import (
	"context"

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
	resp, err := newAdminApp(l.svcCtx.DB).ListAuditLogs(l.ctx, in)
	if err != nil {
		return nil, mapAdminAuditListErr(err)
	}
	return resp, nil
}
