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

type AdminUpdateGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateGiftLogic {
	return &AdminUpdateGiftLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateGiftLogic) AdminUpdateGift(in *super.AdminUpdateGiftReq) (*super.AdminUpdateGiftResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).AdminUpdateGift(l.ctx, in)
	if err != nil {
		if errors.Is(err, adminbiz.ErrGiftNotFound) {
			return nil, errorx.NotFound("礼物不存在")
		}
		if errors.Is(err, giftbiz.ErrInvalidGiftID) || errors.Is(err, giftbiz.ErrEmptyGiftID) {
			return nil, errorx.InvalidArgument("无效礼物 ID")
		}
		if errors.Is(err, adminbiz.ErrEmptyGiftName) || errors.Is(err, adminbiz.ErrEmptyCategory) || errors.Is(err, adminbiz.ErrNegativePrice) {
			return nil, errorx.InvalidArgument(err.Error())
		}
		l.Errorf("[admin] update gift: %v", err)
		return nil, errorx.Internal("更新礼物失败")
	}
	return resp, nil
}
