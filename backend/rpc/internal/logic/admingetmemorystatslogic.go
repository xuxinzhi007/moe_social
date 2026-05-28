package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMemoryStatsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetMemoryStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMemoryStatsLogic {
	return &AdminGetMemoryStatsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetMemoryStatsLogic) AdminGetMemoryStats(in *moe.AdminGetMemoryStatsReq) (*moe.AdminGetMemoryStatsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).GetMemoryStats(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
