package logic

import (
	"context"
	"errors"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
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
	giftID, err := parseGiftID(in.GetGiftId())
	if err != nil {
		return nil, err
	}

	var gift model.Gift
	if err := l.svcCtx.DB.First(&gift, giftID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("礼物不存在")
		}
		l.Errorf("[admin] get gift: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}

	return &super.AdminGetGiftResp{
		Gift: giftModelToProto(gift),
	}, nil
}
