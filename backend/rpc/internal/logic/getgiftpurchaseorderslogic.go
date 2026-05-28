package logic

import (
	"context"
	"errors"

	giftapp "backend/internal/service/gift"
	giftbiz "backend/internal/biz/gift"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftPurchaseOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftPurchaseOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftPurchaseOrdersLogic {
	return &GetGiftPurchaseOrdersLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetGiftPurchaseOrdersLogic) GetGiftPurchaseOrders(in *moe.GetGiftPurchaseOrdersReq) (*moe.GetGiftPurchaseOrdersResp, error) {
	resp, err := giftapp.New(l.svcCtx.DB).GetGiftPurchaseOrders(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, giftbiz.ErrInvalidUserID):
			return nil, errorx.New(400, "无效的用户ID")
		case errors.Is(err, giftbiz.ErrUserNotFound):
			return nil, errorx.New(404, "用户不存在")
		default:
			l.Errorf("[gift] list purchase orders: %v", err)
			return nil, errorx.Internal("查询订单列表失败")
		}
	}
	return resp, nil
}
