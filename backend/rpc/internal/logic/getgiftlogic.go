package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftLogic {
	return &GetGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGiftLogic) GetGift(in *super.GetGiftReq) (*super.GetGiftResp, error) {
	giftID, err := strconv.ParseUint(in.GetGiftId(), 10, 64)
	if err != nil {
		return &super.GetGiftResp{
			Success: false,
			Message: "invalid gift id",
		}, nil
	}

	db := l.svcCtx.DB
	var gift model.Gift
	if err := db.First(&gift, giftID).Error; err != nil {
		return &super.GetGiftResp{
			Success: false,
			Message: "gift not found",
		}, nil
	}

	return &super.GetGiftResp{
		Success: true,
		Message: "success",
		Gift: &super.Gift{
			Id:          uint64(gift.ID),
			Name:        gift.Name,
			Price:       int32(gift.Price),
			Icon:        gift.Icon,
			Description: gift.Description,
			CreatedAt:  gift.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:  gift.UpdatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
