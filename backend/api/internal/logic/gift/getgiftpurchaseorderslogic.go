package gift

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftPurchaseOrdersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGiftPurchaseOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftPurchaseOrdersLogic {
	return &GetGiftPurchaseOrdersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGiftPurchaseOrdersLogic) GetGiftPurchaseOrders(req *types.GetGiftPurchaseOrdersReq) (resp *types.GetGiftPurchaseOrdersResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGiftPurchaseOrders(l.ctx, &super.GetGiftPurchaseOrdersReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetGiftPurchaseOrdersResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
			Total:    0,
		}, nil
	}

	data := make([]types.GiftPurchaseOrder, 0, len(rpcResp.Orders))
	for _, o := range rpcResp.Orders {
		data = append(data, types.GiftPurchaseOrder{
			Id:          o.Id,
			UserId:      o.UserId,
			OrderNo:     o.OrderNo,
			GiftId:      o.GiftId,
			GiftName:    o.GiftName,
			Quantity:    int(o.Quantity),
			UnitPrice:   o.UnitPrice,
			TotalAmount: o.TotalAmount,
			PayMethod:   o.PayMethod,
			Status:      o.Status,
			CreatedAt:   o.CreatedAt,
		})
	}

	return &types.GetGiftPurchaseOrdersResp{
		BaseResp: common.HandleRPCError(nil, "获取礼物购买订单成功"),
		Data:     data,
		Total:    int(rpcResp.Total),
	}, nil
}
