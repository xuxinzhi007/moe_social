package giftbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	giftv1 "backend/api/gift/v1"
	"backend/internal/platform/socialhook"
	"backend/pkg/achievement"
	"backend/model"

	"gorm.io/gorm"
)

// Send 赠送礼物。
func Send(ctx context.Context, store GiftStore, fromRaw, toRaw, giftRaw string, quantity int32) (*giftv1.SendGiftReply, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	fromUserID, err := strconv.ParseUint(strings.TrimSpace(fromRaw), 10, 64)
	if err != nil || fromUserID == 0 {
		return &giftv1.SendGiftReply{Success: false, Message: "invalid sender id"}, nil
	}
	toUserID, err := strconv.ParseUint(strings.TrimSpace(toRaw), 10, 64)
	if err != nil || toUserID == 0 {
		return &giftv1.SendGiftReply{Success: false, Message: "invalid receiver id"}, nil
	}
	giftID, err := strconv.ParseUint(strings.TrimSpace(giftRaw), 10, 64)
	if err != nil || giftID == 0 {
		return &giftv1.SendGiftReply{Success: false, Message: "invalid gift id"}, nil
	}
	if quantity <= 0 {
		quantity = 1
	}

	sender, err := store.GetUserByID(ctx, uint(fromUserID))
	if err != nil {
		return &giftv1.SendGiftReply{Success: false, Message: "sender not found"}, nil
	}
	receiver, err := store.GetUserByID(ctx, uint(toUserID))
	if err != nil {
		return &giftv1.SendGiftReply{Success: false, Message: "receiver not found"}, nil
	}
	gift, err := store.GetGiftByID(ctx, uint(giftID))
	if err != nil {
		return &giftv1.SendGiftReply{Success: false, Message: "gift not found"}, nil
	}

	var record model.GiftRecord
	err = store.Transaction(ctx, func(tx GiftTx) error {
		s, err := tx.GetUserForUpdate(uint(fromUserID))
		if err != nil {
			return err
		}
		recv, err := tx.GetUserForUpdate(uint(toUserID))
		if err != nil {
			return err
		}
		receiver = recv

		cost := float64(gift.Price) * float64(quantity)
		stock, errStock := tx.FindUserGiftStock(uint(fromUserID), uint(giftID))
		useStock := errStock == nil && stock.Quantity >= int(quantity)

		if useStock {
			if err := tx.UpdateUserGiftStockQuantity(&stock, stock.Quantity-int(quantity)); err != nil {
				return err
			}
		} else {
			if s.Balance < cost {
				return ErrInsufficientBal
			}
			if err := tx.DeductBalance(uint(fromUserID), cost); err != nil {
				return err
			}
			tr := model.Transaction{
				UserID: uint(fromUserID), Amount: cost, Type: "consume", Status: "success",
				Description: fmt.Sprintf("赠送礼物「%s」×%d 给好友", gift.Name, quantity),
			}
			if err := tx.CreateTransaction(&tr); err != nil {
				return err
			}
		}

		record = model.GiftRecord{
			FromUserID: uint(fromUserID), ToUserID: uint(toUserID),
			GiftID: uint(giftID), Quantity: int(quantity),
		}
		if err := tx.CreateGiftRecord(&record); err != nil {
			return err
		}
		addCharm := gift.Price * int(quantity)
		addValue := float64(gift.Price) * float64(quantity)
		return tx.UpdateReceiverGiftStats(uint(toUserID), addCharm, addValue)
	})

	if err != nil {
		if errors.Is(err, ErrInsufficientBal) {
			return &giftv1.SendGiftReply{Success: false, Message: "insufficient balance"}, nil
		}
		return &giftv1.SendGiftReply{Success: false, Message: "failed to send gift: " + err.Error()}, nil
	}

	addValue := float64(gift.Price) * float64(quantity)
	achUnlocks := socialhook.ApplyGiftSentAchievements(store.Raw(), socialhook.GiftSentMeta{
		UserID: uint(fromUserID), GiftCount: int(quantity), GiftValue: addValue,
	})

	giftProto := GiftToProto(gift, 0)
	return &giftv1.SendGiftReply{
		Success: true, Message: "gift sent successfully", NewAchievements: achievement.UnlocksToGiftV1(achUnlocks),
		Record: RecordToProto(record, sender, receiver, giftProto),
	}, nil
}
