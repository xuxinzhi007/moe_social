package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetGrowthStatsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetGrowthStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetGrowthStatsLogic {
	return &AdminGetGrowthStatsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetGrowthStatsLogic) AdminGetGrowthStats(_ *types.EmptyReq) (*types.AdminGetGrowthStatsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminGetGrowthStats(l.ctx, &moe.AdminGetGrowthStatsReq{})
	if err != nil {
		return &types.AdminGetGrowthStatsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetGrowthStatsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminGrowthStatsToTypes(rpcResp.GetStats()),
	}, nil
}
