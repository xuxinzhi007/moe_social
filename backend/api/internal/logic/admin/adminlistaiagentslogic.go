package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAiAgentsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAiAgentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiAgentsLogic {
	return &AdminListAiAgentsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAiAgentsLogic) AdminListAiAgents(req *types.AdminListAiAgentsReq) (*types.AdminListAiAgentsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAiAgents(l.ctx, &moe.AdminListAiAgentsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListAiAgentsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAiAgentItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminAiAgentToTypes(item)
	}
	return &types.AdminListAiAgentsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListAiAgentsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
