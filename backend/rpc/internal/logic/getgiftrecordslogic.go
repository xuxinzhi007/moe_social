package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftRecordsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftRecordsLogic {
	return &GetGiftRecordsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGiftRecordsLogic) GetGiftRecords(in *super.GetGiftRecordsReq) (*super.GetGiftRecordsResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return &super.GetGiftRecordsResp{
			Records: nil,
			Total:  0,
		}, nil
	}

	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}

	db := l.svcCtx.DB
	var giftRecords []model.GiftRecord
	var total int64

	if err := db.Model(&model.GiftRecord{}).Where("from_user_id = ? OR to_user_id = ?", userID, userID).Count(&total).Error; err != nil {
		return &super.GetGiftRecordsResp{
			Records: nil,
			Total:   0,
		}, nil
	}

	offset := (int(page) - 1) * int(pageSize)
	if err := db.Where("from_user_id = ? OR to_user_id = ?", userID, userID).Preload("Gift").Order("created_at DESC").Offset(offset).Limit(int(pageSize)).Find(&giftRecords).Error; err != nil {
		return &super.GetGiftRecordsResp{
			Records: nil,
			Total:   0,
		}, nil
	}

	recordList := make([]*super.GiftRecord, len(giftRecords))
	for i, record := range giftRecords {
		var fromUser, toUser model.User
		db.First(&fromUser, record.FromUserID)
		db.First(&toUser, record.ToUserID)

		var gift *super.Gift
		if record.Gift.ID != 0 {
			gift = &super.Gift{
				Id:          uint64(record.Gift.ID),
				Name:        record.Gift.Name,
				Price:       int32(record.Gift.Price),
				Icon:        record.Gift.Icon,
				Description: record.Gift.Description,
			}
		}

		recordList[i] = &super.GiftRecord{
			Id:           uint64(record.ID),
			FromUserId:   uint64(record.FromUserID),
			FromUserName: fromUser.Username,
			ToUserId:     uint64(record.ToUserID),
			ToUserName:   toUser.Username,
			GiftId:       uint64(record.GiftID),
			Gift:         gift,
			Quantity:     int32(record.Quantity),
			CreatedAt:   record.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &super.GetGiftRecordsResp{
		Records: recordList,
		Total:   int32(total),
	}, nil
}
