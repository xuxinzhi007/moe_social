package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapGiftsLogic {
	return &AdminBootstrapGiftsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminBootstrapGiftsLogic) AdminBootstrapGifts(in *moe.AdminBootstrapGiftsReq) (*moe.AdminBootstrapGiftsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).AdminBootstrapGifts(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] bootstrap gifts: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}
	return resp, nil
}
