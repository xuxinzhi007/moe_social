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

type AdminGetMoeToolStatsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeToolStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeToolStatsLogic {
	return &AdminGetMoeToolStatsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetMoeToolStatsLogic) AdminGetMoeToolStats(req *types.AdminGetMoeToolStatsReq) (*types.AdminGetMoeToolStatsResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminGetMoeToolStats(l.ctx, &super.AdminGetMoeToolStatsReq{
		From:     req.From,
		To:       req.To,
		AgentKey: req.AgentKey,
		Tool:     req.Tool,
	})
	if err != nil {
		return &types.AdminGetMoeToolStatsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetMoeToolStatsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.ToolStatsFromRPC(rpcResp),
	}, nil
}
