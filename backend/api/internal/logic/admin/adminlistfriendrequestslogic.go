package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListFriendRequestsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListFriendRequestsLogic {
	return &AdminListFriendRequestsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListFriendRequestsLogic) AdminListFriendRequests(req *types.AdminListFriendRequestsReq) (*types.AdminListFriendRequestsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListFriendRequests(l.ctx, &moe.AdminListFriendRequestsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Status:   req.Status,
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListFriendRequestsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminFriendRequestItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminFriendRequestToTypes(item)
	}
	return &types.AdminListFriendRequestsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListFriendRequestsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
