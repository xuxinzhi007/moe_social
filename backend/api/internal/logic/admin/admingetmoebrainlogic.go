package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeBrainLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeBrainLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainLogic {
	return &AdminGetMoeBrainLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetMoeBrainLogic) AdminGetMoeBrain(req *types.AdminGetMoeBrainReq) (*types.AdminGetMoeBrainResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminGetMoeBrain(l.ctx, &super.AdminGetMoeBrainReq{
		AgentKey: req.AgentKey,
	})
	if err != nil {
		return &types.AdminGetMoeBrainResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetMoeBrainResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.BrainDataFromRPC(rpcResp),
	}, nil
}
