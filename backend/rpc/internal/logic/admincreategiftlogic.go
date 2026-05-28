package logic

import (
	"context"
	"errors"

	adminbiz "backend/internal/biz/admin"
	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateGiftLogic {
	return &AdminCreateGiftLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateGiftLogic) AdminCreateGift(in *moe.AdminCreateGiftReq) (*moe.AdminCreateGiftResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).AdminCreateGift(l.ctx, in)
	if err != nil {
		if errors.Is(err, adminbiz.ErrEmptyGiftName) {
			return nil, errorx.InvalidArgument("礼物名称不能为空")
		}
		if errors.Is(err, adminbiz.ErrNegativePrice) {
			return nil, errorx.InvalidArgument("价格不能为负数")
		}
		l.Errorf("[admin] create gift: %v", err)
		return nil, errorx.Internal("创建礼物失败")
	}
	return resp, nil
}
