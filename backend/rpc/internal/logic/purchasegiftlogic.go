package logic

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type PurchaseGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewPurchaseGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PurchaseGiftLogic {
	return &PurchaseGiftLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *PurchaseGiftLogic) PurchaseGift(in *moe.PurchaseGiftReq) (*moe.PurchaseGiftResp, error) {
	return giftapp.New(l.svcCtx.DB).PurchaseGift(l.ctx, in)
}
