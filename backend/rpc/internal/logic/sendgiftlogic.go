package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type SendGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSendGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendGiftLogic {
	return &SendGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SendGiftLogic) SendGift(in *super.SendGiftReq) (*super.SendGiftResp, error) {
	fromUserID, err := strconv.ParseUint(in.GetFromUserId(), 10, 64)
	if err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "invalid sender id",
		}, nil
	}

	toUserID, err := strconv.ParseUint(in.GetToUserId(), 10, 64)
	if err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "invalid receiver id",
		}, nil
	}

	giftID, err := strconv.ParseUint(in.GetGiftId(), 10, 64)
	if err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "invalid gift id",
		}, nil
	}

	quantity := in.GetQuantity()
	if quantity <= 0 {
		quantity = 1
	}

	db := l.svcCtx.DB

	var sender model.User
	if err := db.First(&sender, fromUserID).Error; err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "sender not found",
		}, nil
	}

	var receiver model.User
	if err := db.First(&receiver, toUserID).Error; err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "receiver not found",
		}, nil
	}

	var gift model.Gift
	if err := db.First(&gift, giftID).Error; err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "gift not found",
		}, nil
	}

	totalCost := float64(gift.Price * int(quantity))
	if sender.Balance < totalCost {
		return &super.SendGiftResp{
			Success: false,
			Message: "insufficient balance",
		}, nil
	}

	var record model.GiftRecord
	err = db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&sender).Update("balance", sender.Balance-totalCost).Error; err != nil {
			return err
		}

		record = model.GiftRecord{
			FromUserID: uint(fromUserID),
			ToUserID:   uint(toUserID),
			GiftID:     uint(giftID),
			Quantity:   int(quantity),
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return &super.SendGiftResp{
			Success: false,
			Message: "failed to send gift: " + err.Error(),
		}, nil
	}

	return &super.SendGiftResp{
		Success: true,
		Message: "gift sent successfully",
		Record: &super.GiftRecord{
			Id:            uint64(record.ID),
			FromUserId:    uint64(record.FromUserID),
			FromUserName:  sender.Username,
			ToUserId:      uint64(record.ToUserID),
			ToUserName:    receiver.Username,
			GiftId:        uint64(record.GiftID),
			Gift: &super.Gift{
				Id:          uint64(gift.ID),
				Name:        gift.Name,
				Price:       int32(gift.Price),
				Icon:        gift.Icon,
				Description: gift.Description,
			},
			Quantity:  int32(record.Quantity),
			CreatedAt: record.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
