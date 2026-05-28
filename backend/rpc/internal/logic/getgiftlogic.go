package logic

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftLogic {
	return &GetGiftLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetGiftLogic) GetGift(in *moe.GetGiftReq) (*moe.GetGiftResp, error) {
	return giftapp.New(l.svcCtx.DB).GetGift(l.ctx, in)
}
