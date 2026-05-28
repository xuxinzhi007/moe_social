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
func Purchase(ctx context.Context, store GiftStore, userRaw, giftRaw string, qty int32) (*moe.PurchaseGiftResp, error) {
	if store == nil {
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

	gift, err := store.GetGiftByID(ctx, uint(giftID))
	if err != nil {
		return &moe.PurchaseGiftResp{Success: false, Message: "gift not found"}, nil
	}

	cost := float64(gift.Price) * float64(qty)
	var newBal float64
	var owned int32
	var orderNo string

	err = store.Transaction(ctx, func(tx GiftTx) error {
		if err := tx.DeductBalance(uint(userID), cost); err != nil {
			return err
		}
		u, err := tx.GetUser(uint(userID))
		if err != nil {
			return err
		}
		newBal = u.Balance

		st, err := tx.FindUserGiftStock(uint(userID), uint(giftID))
		if errors.Is(err, gorm.ErrRecordNotFound) {
			st = model.UserGiftStock{UserID: uint(userID), GiftID: uint(giftID), Quantity: int(qty)}
			if err := tx.CreateUserGiftStock(&st); err != nil {
				return err
			}
		} else if err != nil {
			return err
		} else {
			st.Quantity += int(qty)
			if err := tx.SaveUserGiftStock(&st); err != nil {
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
		if err := tx.CreatePurchaseOrder(&po); err != nil {
			return err
		}
		tr := model.Transaction{
			UserID: uint(userID), Amount: cost, Type: "consume", Status: "success",
			Description: fmt.Sprintf("购买礼物「%s」×%d（订单号 %s）", gift.Name, qty, orderNo),
		}
		return tx.CreateTransaction(&tr)
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
