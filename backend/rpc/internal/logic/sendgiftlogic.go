package logic

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSendGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendGiftLogic {
	return &SendGiftLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *SendGiftLogic) SendGift(in *moe.SendGiftReq) (*moe.SendGiftResp, error) {
	return giftapp.New(l.svcCtx.DB).SendGift(l.ctx, in)
}
