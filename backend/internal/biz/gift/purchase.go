package giftbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// Purchase 购买礼物入库。
func Purchase(ctx context.Context, db *gorm.DB, userRaw, giftRaw string, qty int32) (*moe.PurchaseGiftResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userRaw), 10, 64)
	if err != nil || userID == 0 {
		return &moe.PurchaseGiftResp{Success: false, Message: "invalid user id"}, nil
	}
	giftID, err := strconv.ParseUint(strings.TrimSpace(giftRaw), 10, 64)
	if err != nil || giftID == 0 {
		return &moe.PurchaseGiftResp{Success: false, Message: "invalid gift id"}, nil
	}
	if qty <= 0 {
		qty = 1
	}

	var gift model.Gift
	if err := db.WithContext(ctx).First(&gift, giftID).Error; err != nil {
		return &moe.PurchaseGiftResp{Success: false, Message: "gift not found"}, nil
	}

	cost := float64(gift.Price) * float64(qty)
	var newBal float64
	var owned int32
	var orderNo string

	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&model.User{}).Where("id = ? AND balance >= ?", userID, cost).
			Update("balance", gorm.Expr("balance - ?", cost))
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected != 1 {
			return ErrInsufficientBal
		}
		var u model.User
		if err := tx.First(&u, userID).Error; err != nil {
			return err
		}
		newBal = u.Balance

		var st model.UserGiftStock
		err := tx.Where("user_id = ? AND gift_id = ?", userID, giftID).First(&st).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			st = model.UserGiftStock{UserID: uint(userID), GiftID: uint(giftID), Quantity: int(qty)}
			if err := tx.Create(&st).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		} else {
			st.Quantity += int(qty)
			if err := tx.Save(&st).Error; err != nil {
				return err
			}
		}
		owned = int32(st.Quantity)

		orderNo = "GFP" + strconv.FormatInt(time.Now().UnixNano(), 10)
		po := model.GiftPurchaseOrder{
			UserID: uint(userID), OrderNo: orderNo, GiftID: uint(giftID), GiftName: gift.Name,
			Quantity: int(qty), UnitPrice: float64(gift.Price), TotalAmount: cost,
			PayMethod: "wallet", Status: "paid",
		}
		if err := tx.Create(&po).Error; err != nil {
			return err
		}
		tr := model.Transaction{
			UserID: uint(userID), Amount: cost, Type: "consume", Status: "success",
			Description: fmt.Sprintf("购买礼物「%s」×%d（订单号 %s）", gift.Name, qty, orderNo),
		}
		return tx.Create(&tr).Error
	})

	if err != nil {
		if errors.Is(err, ErrInsufficientBal) {
			return &moe.PurchaseGiftResp{Success: false, Message: "insufficient balance"}, nil
		}
		return &moe.PurchaseGiftResp{Success: false, Message: "purchase failed: " + err.Error()}, nil
	}

	return &moe.PurchaseGiftResp{
		Success: true, Message: "ok", NewBalance: newBal, OwnedQuantity: owned, OrderNo: orderNo,
	}, nil
}
