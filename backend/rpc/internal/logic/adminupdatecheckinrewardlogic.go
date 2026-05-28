package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateCheckInRewardLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateCheckInRewardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateCheckInRewardLogic {
	return &AdminUpdateCheckInRewardLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateCheckInRewardLogic) AdminUpdateCheckInReward(in *moe.AdminUpdateCheckInRewardReq) (*moe.AdminUpdateCheckInRewardResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).UpdateCheckInReward(l.ctx, in)
	if err != nil {
		return nil, mapAdminGrowthErr(err)
	}
	return resp, nil
}
