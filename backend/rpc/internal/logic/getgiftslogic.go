package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftsLogic {
	return &GetGiftsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGiftsLogic) GetGifts(in *super.GetGiftsReq) (*super.GetGiftsResp, error) {
	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}

	db := l.svcCtx.DB
	var gifts []model.Gift
	var total int64

	db.Model(&model.Gift{}).Count(&total)

	offset := (int(page) - 1) * int(pageSize)
	db.Offset(offset).Limit(int(pageSize)).Find(&gifts)

	stockByGift := map[uint]int32{}
	viewer := in.GetViewerUserId()
	if viewer != "" {
		if uid, err := strconv.ParseUint(viewer, 10, 64); err == nil {
			if len(gifts) > 0 {
				ids := make([]uint, 0, len(gifts))
				for _, g := range gifts {
					ids = append(ids, g.ID)
				}
				var rows []model.UserGiftStock
				_ = db.Where("user_id = ? AND gift_id IN ?", uid, ids).Find(&rows).Error
				for _, r := range rows {
					stockByGift[r.GiftID] = int32(r.Quantity)
				}
			}
		}
	}

	giftList := make([]*super.Gift, len(gifts))
	for i, gift := range gifts {
		giftList[i] = &super.Gift{
			Id:             uint64(gift.ID),
			Name:           gift.Name,
			Price:          int32(gift.Price),
			Icon:           gift.Icon,
			Description:    gift.Description,
			CreatedAt:      gift.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:      gift.UpdatedAt.Format("2006-01-02 15:04:05"),
			OwnedQuantity:  stockByGift[gift.ID],
		}
	}

	return &super.GetGiftsResp{
		Gifts: giftList,
		Total: int32(total),
	}, nil
}
