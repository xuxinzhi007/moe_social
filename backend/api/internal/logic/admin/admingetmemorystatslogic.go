package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMemoryStatsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMemoryStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMemoryStatsLogic {
	return &AdminGetMemoryStatsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetMemoryStatsLogic) AdminGetMemoryStats(_ *types.EmptyReq) (*types.AdminGetMemoryStatsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminGetMemoryStats(l.ctx, &super.AdminGetMemoryStatsReq{})
	if err != nil {
		return &types.AdminGetMemoryStatsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetMemoryStatsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminMemoryStatsToTypes(rpcResp.GetStats()),
	}, nil
}
