package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAccountsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAccountsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAccountsLogic {
	return &AdminListAccountsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAccountsLogic) AdminListAccounts(req *types.AdminListAccountsReq) (*types.AdminListAccountsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAccounts(l.ctx, &super.AdminListAccountsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListAccountsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAccountItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminAccountToTypes(item)
	}
	return &types.AdminListAccountsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListAccountsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
