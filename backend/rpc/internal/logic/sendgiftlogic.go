package logic

import (
	"context"
	"errors"
	"fmt"
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

	var record model.GiftRecord
	err = db.Transaction(func(tx *gorm.DB) error {
		var s model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&s, fromUserID).Error; err != nil {
			return err
		}
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&receiver, toUserID).Error; err != nil {
			return err
		}

		cost := float64(gift.Price) * float64(quantity)

		var stock model.UserGiftStock
		errStock := tx.Where("user_id = ? AND gift_id = ?", fromUserID, giftID).First(&stock).Error
		useStock := errStock == nil && stock.Quantity >= int(quantity)

		if useStock {
			if err := tx.Model(&stock).Update("quantity", stock.Quantity-int(quantity)).Error; err != nil {
				return err
			}
		} else {
			if s.Balance < cost {
				return errors.New("insufficient balance")
			}
			res := tx.Model(&model.User{}).Where("id = ? AND balance >= ?", fromUserID, cost).
				Update("balance", gorm.Expr("balance - ?", cost))
			if res.Error != nil {
				return res.Error
			}
			if res.RowsAffected != 1 {
				return errors.New("insufficient balance")
			}
			tr := model.Transaction{
				UserID:      uint(fromUserID),
				Amount:      cost,
				Type:        "consume",
				Status:      "success",
				Description: fmt.Sprintf("赠送礼物「%s」×%d 给好友", gift.Name, quantity),
			}
			if err := tx.Create(&tr).Error; err != nil {
				return err
			}
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

		addCharm := gift.Price * int(quantity)
		addValue := float64(gift.Price) * float64(quantity)
		if err := tx.Model(&model.User{}).Where("id = ?", toUserID).Updates(map[string]interface{}{
			"gift_charm":          gorm.Expr("gift_charm + ?", addCharm),
			"received_gift_value": gorm.Expr("received_gift_value + ?", addValue),
		}).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		msg := err.Error()
		if msg == "insufficient balance" {
			return &super.SendGiftResp{
				Success: false,
				Message: "insufficient balance",
			}, nil
		}
		return &super.SendGiftResp{
			Success: false,
			Message: "failed to send gift: " + msg,
		}, nil
	}

	return &super.SendGiftResp{
		Success: true,
		Message: "gift sent successfully",
		Record: &super.GiftRecord{
			Id:           uint64(record.ID),
			FromUserId:   uint64(record.FromUserID),
			FromUserName: sender.Username,
			ToUserId:     uint64(record.ToUserID),
			ToUserName:   receiver.Username,
			GiftId:       uint64(record.GiftID),
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
