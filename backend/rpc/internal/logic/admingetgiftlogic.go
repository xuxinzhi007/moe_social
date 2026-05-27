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

type AdminGetGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetGiftLogic {
	return &AdminGetGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminGetGiftLogic) AdminGetGift(in *super.AdminGetGiftReq) (*super.AdminGetGiftResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).AdminGetGift(l.ctx, in)
	if err != nil {
		if errors.Is(err, adminbiz.ErrGiftNotFound) {
			return nil, errorx.NotFound("礼物不存在")
		}
		if errors.Is(err, giftbiz.ErrInvalidGiftID) || errors.Is(err, giftbiz.ErrEmptyGiftID) {
			return nil, errorx.InvalidArgument("无效礼物 ID")
		}
		l.Errorf("[admin] get gift: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}
	return resp, nil
}
