package giftbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"backend/internal/platform/socialhook"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// Send 赠送礼物。
func Send(ctx context.Context, db *gorm.DB, fromRaw, toRaw, giftRaw string, quantity int32) (*super.SendGiftResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	fromUserID, err := strconv.ParseUint(strings.TrimSpace(fromRaw), 10, 64)
	if err != nil || fromUserID == 0 {
		return &super.SendGiftResp{Success: false, Message: "invalid sender id"}, nil
	}
	toUserID, err := strconv.ParseUint(strings.TrimSpace(toRaw), 10, 64)
	if err != nil || toUserID == 0 {
		return &super.SendGiftResp{Success: false, Message: "invalid receiver id"}, nil
	}
	giftID, err := strconv.ParseUint(strings.TrimSpace(giftRaw), 10, 64)
	if err != nil || giftID == 0 {
		return &super.SendGiftResp{Success: false, Message: "invalid gift id"}, nil
	}
	if quantity <= 0 {
		quantity = 1
	}

	var sender model.User
	if err := db.WithContext(ctx).First(&sender, fromUserID).Error; err != nil {
		return &super.SendGiftResp{Success: false, Message: "sender not found"}, nil
	}
	var receiver model.User
	if err := db.WithContext(ctx).First(&receiver, toUserID).Error; err != nil {
		return &super.SendGiftResp{Success: false, Message: "receiver not found"}, nil
	}
	var gift model.Gift
	if err := db.WithContext(ctx).First(&gift, giftID).Error; err != nil {
		return &super.SendGiftResp{Success: false, Message: "gift not found"}, nil
	}

	var record model.GiftRecord
	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var s model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&s, fromUserID).Error; err != nil {
			return err
		}
		var recv model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&recv, toUserID).Error; err != nil {
			return err
		}
		receiver = recv

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
				return ErrInsufficientBal
			}
			res := tx.Model(&model.User{}).Where("id = ? AND balance >= ?", fromUserID, cost).
				Update("balance", gorm.Expr("balance - ?", cost))
			if res.Error != nil {
				return res.Error
			}
			if res.RowsAffected != 1 {
				return ErrInsufficientBal
			}
			tr := model.Transaction{
				UserID: uint(fromUserID), Amount: cost, Type: "consume", Status: "success",
				Description: fmt.Sprintf("赠送礼物「%s」×%d 给好友", gift.Name, quantity),
			}
			if err := tx.Create(&tr).Error; err != nil {
				return err
			}
		}

		record = model.GiftRecord{
			FromUserID: uint(fromUserID), ToUserID: uint(toUserID),
			GiftID: uint(giftID), Quantity: int(quantity),
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}
		addCharm := gift.Price * int(quantity)
		addValue := float64(gift.Price) * float64(quantity)
		return tx.Model(&model.User{}).Where("id = ?", toUserID).Updates(map[string]interface{}{
			"gift_charm":          gorm.Expr("gift_charm + ?", addCharm),
			"received_gift_value": gorm.Expr("received_gift_value + ?", addValue),
		}).Error
	})

	if err != nil {
		if errors.Is(err, ErrInsufficientBal) {
			return &super.SendGiftResp{Success: false, Message: "insufficient balance"}, nil
		}
		return &super.SendGiftResp{Success: false, Message: "failed to send gift: " + err.Error()}, nil
	}

	addValue := float64(gift.Price) * float64(quantity)
	achUnlocks := socialhook.ApplyGiftSentAchievements(db, socialhook.GiftSentMeta{
		UserID: uint(fromUserID), GiftCount: int(quantity), GiftValue: addValue,
	})

	giftProto := GiftToProto(gift, 0)
	return &super.SendGiftResp{
		Success: true, Message: "gift sent successfully", NewAchievements: achUnlocks,
		Record: RecordToProto(record, sender, receiver, giftProto),
	}, nil
}
