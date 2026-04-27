package logic

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type PurchaseGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewPurchaseGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PurchaseGiftLogic {
	return &PurchaseGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *PurchaseGiftLogic) PurchaseGift(in *super.PurchaseGiftReq) (*super.PurchaseGiftResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return &super.PurchaseGiftResp{
			Success: false,
			Message: "invalid user id",
		}, nil
	}
	giftID, err := strconv.ParseUint(in.GetGiftId(), 10, 64)
	if err != nil {
		return &super.PurchaseGiftResp{
			Success: false,
			Message: "invalid gift id",
		}, nil
	}
	qty := in.GetQuantity()
	if qty <= 0 {
		qty = 1
	}

	db := l.svcCtx.DB
	var gift model.Gift
	if err := db.First(&gift, giftID).Error; err != nil {
		return &super.PurchaseGiftResp{
			Success: false,
			Message: "gift not found",
		}, nil
	}

	cost := float64(gift.Price) * float64(qty)
	var newBal float64
	var owned int32
	var orderNo string

	err = db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&model.User{}).Where("id = ? AND balance >= ?", userID, cost).
			Update("balance", gorm.Expr("balance - ?", cost))
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected != 1 {
			return errors.New("insufficient balance")
		}
		var u model.User
		if err := tx.First(&u, userID).Error; err != nil {
			return err
		}
		newBal = u.Balance

		var st model.UserGiftStock
		err := tx.Where("user_id = ? AND gift_id = ?", userID, giftID).First(&st).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			st = model.UserGiftStock{
				UserID:   uint(userID),
				GiftID:   uint(giftID),
				Quantity: int(qty),
			}
			if err := tx.Create(&st).Error; err != nil {
				return err
			}
			owned = int32(st.Quantity)
			orderNo = "GFP" + strconv.FormatInt(time.Now().UnixNano(), 10)
			po := model.GiftPurchaseOrder{
				UserID:      uint(userID),
				OrderNo:     orderNo,
				GiftID:      uint(giftID),
				GiftName:    gift.Name,
				Quantity:    int(qty),
				UnitPrice:   float64(gift.Price),
				TotalAmount: cost,
				PayMethod:   "wallet",
				Status:      "paid",
			}
			if err := tx.Create(&po).Error; err != nil {
				return err
			}
			tr := model.Transaction{
				UserID:      uint(userID),
				Amount:      cost,
				Type:        "consume",
				Status:      "success",
				Description: fmt.Sprintf("购买礼物「%s」×%d（订单号 %s）", gift.Name, qty, orderNo),
			}
			if err := tx.Create(&tr).Error; err != nil {
				return err
			}
			return nil
		}
		if err != nil {
			return err
		}
		st.Quantity += int(qty)
		if err := tx.Save(&st).Error; err != nil {
			return err
		}
		owned = int32(st.Quantity)

		orderNo = "GFP" + strconv.FormatInt(time.Now().UnixNano(), 10)
		po := model.GiftPurchaseOrder{
			UserID:      uint(userID),
			OrderNo:     orderNo,
			GiftID:      uint(giftID),
			GiftName:    gift.Name,
			Quantity:    int(qty),
			UnitPrice:   float64(gift.Price),
			TotalAmount: cost,
			PayMethod:   "wallet",
			Status:      "paid",
		}
		if err := tx.Create(&po).Error; err != nil {
			return err
		}
		tr := model.Transaction{
			UserID:      uint(userID),
			Amount:      cost,
			Type:        "consume",
			Status:      "success",
			Description: fmt.Sprintf("购买礼物「%s」×%d（订单号 %s）", gift.Name, qty, orderNo),
		}
		if err := tx.Create(&tr).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		if err.Error() == "insufficient balance" {
			return &super.PurchaseGiftResp{
				Success: false,
				Message: "insufficient balance",
			}, nil
		}
		return &super.PurchaseGiftResp{
			Success: false,
			Message: "purchase failed: " + err.Error(),
		}, nil
	}

	return &super.PurchaseGiftResp{
		Success:        true,
		Message:        "ok",
		NewBalance:     newBal,
		OwnedQuantity:  owned,
		OrderNo:        orderNo,
	}, nil
}
