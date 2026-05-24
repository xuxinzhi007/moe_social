package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListVipOrdersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListVipOrdersLogic {
	return &AdminListVipOrdersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListVipOrdersLogic) AdminListVipOrders(req *types.AdminListVipOrdersReq) (resp *types.AdminListVipOrdersResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListVipOrders(l.ctx, &super.AdminListVipOrdersReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		UserId:   req.UserId,
		Keyword:  req.Keyword,
		Status:   req.Status,
	})
	if err != nil {
		return &types.AdminListVipOrdersResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.VipOrder, 0, len(rpcResp.GetOrders()))
	for _, o := range rpcResp.GetOrders() {
		items = append(items, common.RpcVipOrderToTypes(o))
	}

	return &types.AdminListVipOrdersResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListVipOrdersData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
