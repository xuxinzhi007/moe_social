package logic

import (
	"context"
	"errors"

	adminbiz "backend/internal/biz/admin"
	giftbiz "backend/internal/biz/gift"
	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteGiftLogic {
	return &AdminDeleteGiftLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteGiftLogic) AdminDeleteGift(in *super.AdminDeleteGiftReq) (*super.AdminDeleteGiftResp, error) {
	_, err := adminapp.New(l.svcCtx.DB).AdminDeleteGift(l.ctx, in)
	if err != nil {
		if errors.Is(err, adminbiz.ErrGiftNotFound) {
			return nil, errorx.NotFound("礼物不存在")
		}
		if errors.Is(err, giftbiz.ErrInvalidGiftID) || errors.Is(err, giftbiz.ErrEmptyGiftID) {
			return nil, errorx.InvalidArgument("无效礼物 ID")
		}
		l.Errorf("[admin] delete gift: %v", err)
		return nil, errorx.Internal("删除礼物失败")
	}
	return &super.AdminDeleteGiftResp{}, nil
}
