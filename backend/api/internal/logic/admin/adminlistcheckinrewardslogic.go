package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListCheckInRewardsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListCheckInRewardsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListCheckInRewardsLogic {
	return &AdminListCheckInRewardsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListCheckInRewardsLogic) AdminListCheckInRewards(_ *types.EmptyReq) (*types.AdminListCheckInRewardsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListCheckInRewards(l.ctx, &moe.AdminListCheckInRewardsReq{})
	if err != nil {
		return &types.AdminListCheckInRewardsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminCheckInRewardItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminCheckInRewardToTypes(item)
	}
	return &types.AdminListCheckInRewardsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     items,
	}, nil
}
