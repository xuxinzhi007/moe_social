package logic

import (
	"context"

	giftapp "backend/internal/service/gift"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftRecordsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftRecordsLogic {
	return &GetGiftRecordsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetGiftRecordsLogic) GetGiftRecords(in *moe.GetGiftRecordsReq) (*moe.GetGiftRecordsResp, error) {
	return giftapp.New(l.svcCtx.DB).GetGiftRecords(l.ctx, in)
}
