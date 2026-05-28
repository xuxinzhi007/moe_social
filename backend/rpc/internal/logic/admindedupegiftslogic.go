package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDedupeGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDedupeGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDedupeGiftsLogic {
	return &AdminDedupeGiftsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDedupeGiftsLogic) AdminDedupeGifts(in *moe.AdminDedupeGiftsReq) (*moe.AdminDedupeGiftsResp, error) {
	_ = in
	return adminapp.New(l.svcCtx.DB).AdminDedupeGifts(l.ctx, in)
}
