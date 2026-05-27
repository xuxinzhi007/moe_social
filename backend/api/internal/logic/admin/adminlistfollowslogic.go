package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListFollowsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListFollowsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListFollowsLogic {
	return &AdminListFollowsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListFollowsLogic) AdminListFollows(req *types.AdminListFollowsReq) (*types.AdminListFollowsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListFollows(l.ctx, &super.AdminListFollowsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
		UserId:   req.UserId,
	})
	if err != nil {
		return &types.AdminListFollowsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminFollowItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminFollowToTypes(item)
	}
	return &types.AdminListFollowsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListFollowsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
