package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGiftPurchaseOrdersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListGiftPurchaseOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGiftPurchaseOrdersLogic {
	return &AdminListGiftPurchaseOrdersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListGiftPurchaseOrdersLogic) AdminListGiftPurchaseOrders(req *types.AdminListGiftPurchaseOrdersReq) (resp *types.AdminListGiftPurchaseOrdersResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rpcResp, err := l.svcCtx.AdminGW.AdminListGiftPurchaseOrders(l.ctx, &moe.AdminListGiftPurchaseOrdersReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		UserId:   req.UserId,
		Keyword:  req.Keyword,
		Status:   req.Status,
	})
	if err != nil {
		return &types.AdminListGiftPurchaseOrdersResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.GiftPurchaseOrder, 0, len(rpcResp.GetOrders()))
	for _, o := range rpcResp.GetOrders() {
		items = append(items, common.RpcGiftPurchaseOrderToTypes(o))
	}

	return &types.AdminListGiftPurchaseOrdersResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListGiftPurchaseOrdersData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
