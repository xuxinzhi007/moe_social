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

type AdminListMoeToolCallsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListMoeToolCallsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMoeToolCallsLogic {
	return &AdminListMoeToolCallsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListMoeToolCallsLogic) AdminListMoeToolCalls(req *types.AdminListMoeToolCallsReq) (*types.AdminListMoeToolCallsResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListMoeToolCalls(l.ctx, &super.AdminListMoeToolCallsReq{
		Page:        int32(req.Page),
		PageSize:    int32(req.PageSize),
		Tool:        req.Tool,
		AgentKey:    req.AgentKey,
		ActorUserId: req.ActorUserId,
		Source:      req.Source,
		OkOnly:      req.OkOnly,
		FailedOnly:  req.FailedOnly,
		From:        req.From,
		To:          req.To,
	})
	if err != nil {
		return &types.AdminListMoeToolCallsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminListMoeToolCallsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.ToolCallsFromRPC(rpcResp),
	}, nil
}
