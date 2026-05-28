package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDashboardLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDashboardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDashboardLogic {
	return &AdminDashboardLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDashboardLogic) AdminDashboard(in *moe.AdminDashboardReq) (*moe.AdminDashboardResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).Dashboard(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
