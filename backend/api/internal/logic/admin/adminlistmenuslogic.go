package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMenusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListMenusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMenusLogic {
	return &AdminListMenusLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListMenusLogic) AdminListMenus(_ *types.EmptyReq) (*types.AdminListMenusResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListMenus(l.ctx, &moe.AdminListMenusReq{})
	if err != nil {
		return &types.AdminListMenusResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminMenuItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminMenuToTypes(item)
	}
	return &types.AdminListMenusResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     items,
	}, nil
}
