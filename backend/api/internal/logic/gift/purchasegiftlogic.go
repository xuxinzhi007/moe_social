package gift

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type PurchaseGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewPurchaseGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PurchaseGiftLogic {
	return &PurchaseGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *PurchaseGiftLogic) PurchaseGift(req *types.PurchaseGiftReq) (resp *types.PurchaseGiftResp, err error) {
	qty := int32(req.Quantity)
	if qty <= 0 {
		qty = 1
	}
	rpcResp, err := l.svcCtx.SuperRpcClient.PurchaseGift(l.ctx, &super.PurchaseGiftReq{
		UserId:   req.UserId,
		GiftId:   req.GiftId,
		Quantity: qty,
	})
	if err != nil {
		return nil, err
	}
	if !rpcResp.Success {
		return &types.PurchaseGiftResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: rpcResp.Message,
				Success: false,
			},
			Data: types.PurchaseGiftData{},
		}, nil
	}
	return &types.PurchaseGiftResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: true,
		},
		Data: types.PurchaseGiftData{
			NewBalance:    rpcResp.NewBalance,
			OwnedQuantity: int(rpcResp.OwnedQuantity),
			OrderNo:       rpcResp.OrderNo,
		},
	}, nil
}
