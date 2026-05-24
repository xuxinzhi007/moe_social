package logic

import (
	"context"

	"backend/model"
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
	return &AdminDeleteGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDeleteGiftLogic) AdminDeleteGift(in *super.AdminDeleteGiftReq) (*super.AdminDeleteGiftResp, error) {
	giftID, err := parseGiftID(in.GetGiftId())
	if err != nil {
		return nil, err
	}

	res := l.svcCtx.DB.Delete(&model.Gift{}, giftID)
	if res.Error != nil {
		l.Errorf("[admin] delete gift: %v", res.Error)
		return nil, errorx.Internal("删除礼物失败")
	}
	if res.RowsAffected == 0 {
		return nil, errorx.NotFound("礼物不存在")
	}

	return &super.AdminDeleteGiftResp{}, nil
}
