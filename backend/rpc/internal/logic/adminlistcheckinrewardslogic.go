package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListCheckInRewardsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListCheckInRewardsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListCheckInRewardsLogic {
	return &AdminListCheckInRewardsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListCheckInRewardsLogic) AdminListCheckInRewards(in *moe.AdminListCheckInRewardsReq) (*moe.AdminListCheckInRewardsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListCheckInRewards(l.ctx, in)
	if err != nil {
		return nil, mapAdminGrowthErr(err)
	}
	return resp, nil
}
