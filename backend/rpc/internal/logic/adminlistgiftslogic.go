package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGiftsLogic {
	return &AdminListGiftsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListGiftsLogic) AdminListGifts(in *moe.AdminListGiftsReq) (*moe.AdminListGiftsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).AdminListGifts(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] list gifts: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}
	return resp, nil
}
