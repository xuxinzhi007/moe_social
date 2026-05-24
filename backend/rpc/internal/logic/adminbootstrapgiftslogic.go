package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapGiftsLogic {
	return &AdminBootstrapGiftsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminBootstrapGiftsLogic) AdminBootstrapGifts(in *super.AdminBootstrapGiftsReq) (*super.AdminBootstrapGiftsResp, error) {
	_ = in

	var count int64
	if err := l.svcCtx.DB.Model(&model.Gift{}).Count(&count).Error; err != nil {
		l.Errorf("[admin] bootstrap gifts count: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}
	if count > 0 {
		return &super.AdminBootstrapGiftsResp{Created: 0}, nil
	}

	utils.SeedDefaultGifts(l.svcCtx.DB)

	if err := l.svcCtx.DB.Model(&model.Gift{}).Count(&count).Error; err != nil {
		l.Errorf("[admin] bootstrap gifts recount: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}

	return &super.AdminBootstrapGiftsResp{
		Created: int32(count),
	}, nil
}
