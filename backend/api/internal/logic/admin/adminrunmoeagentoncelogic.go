package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminRunMoeAgentOnceLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminRunMoeAgentOnceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRunMoeAgentOnceLogic {
	return &AdminRunMoeAgentOnceLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminRunMoeAgentOnceLogic) AdminRunMoeAgentOnce(req *types.AdminRunMoeAgentReq) (*types.AdminRunMoeAgentResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminRunMoeAgentOnce(l.ctx, &super.AdminRunMoeAgentOnceReq{
		AgentKey: req.AgentKey,
	})
	if err != nil {
		return &types.AdminRunMoeAgentResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminRunMoeAgentResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminRunMoeAgentData{
			AgentKey: rpcResp.AgentKey,
			Ok:       rpcResp.Ok,
			Detail:   rpcResp.Detail,
			PostId:   rpcResp.PostId,
		},
	}, nil
}
