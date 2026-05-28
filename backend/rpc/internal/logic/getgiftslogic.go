package logic

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftsLogic {
	return &GetGiftsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetGiftsLogic) GetGifts(in *moe.GetGiftsReq) (*moe.GetGiftsResp, error) {
	return giftapp.New(l.svcCtx.DB).GetGifts(l.ctx, in)
}
