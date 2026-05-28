package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListPostReportsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListPostReportsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListPostReportsLogic {
	return &AdminListPostReportsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListPostReportsLogic) AdminListPostReports(in *moe.AdminListPostReportsReq) (*moe.AdminListPostReportsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListPostReports(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
