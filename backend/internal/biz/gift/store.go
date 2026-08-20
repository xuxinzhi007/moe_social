package giftbiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// GiftStore 礼物持久化（P4-D；默认由 internal/data/gift 实现）。
type GiftStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) GiftStore

	CountGifts(ctx context.Context) (int64, error)
	ListGifts(ctx context.Context, offset, limit int) ([]model.Gift, error)
	FindUserGiftStock(ctx context.Context, userID uint, giftIDs []uint) ([]model.UserGiftStock, error)
	GetGiftByID(ctx context.Context, id uint) (model.Gift, error)
	CountGiftRecords(ctx context.Context, userID uint) (int64, error)
	ListGiftRecords(ctx context.Context, userID uint, offset, limit int) ([]model.GiftRecord, error)
	UserExists(ctx context.Context, userID uint) error
	CountPurchaseOrders(ctx context.Context, userID uint) (int64, error)
	ListPurchaseOrders(ctx context.Context, userID uint, offset, limit int) ([]model.GiftPurchaseOrder, error)
	GetUserByID(ctx context.Context, userID uint) (model.User, error)

	Transaction(ctx context.Context, fn func(GiftTx) error) error
}

// GiftTx 礼物写操作事务。
type GiftTx interface {
	GetGift(id uint) (model.Gift, error)
	GetUser(id uint) (model.User, error)
	GetUserForUpdate(id uint) (model.User, error)
	DeductBalance(userID uint, cost float64) error
	FindUserGiftStock(userID, giftID uint) (model.UserGiftStock, error)
	CreateUserGiftStock(stock *model.UserGiftStock) error
	SaveUserGiftStock(stock *model.UserGiftStock) error
	UpdateUserGiftStockQuantity(stock *model.UserGiftStock, quantity int) error
	CreatePurchaseOrder(order *model.GiftPurchaseOrder) error
	CreateTransaction(tr *model.Transaction) error
	CreateGiftRecord(record *model.GiftRecord) error
	UpdateReceiverGiftStats(toUserID uint, addCharm int, addValue float64) error
}

// SendInTransaction consumes a gift and creates its ordinary gift record in
// a transaction supplied by a caller that owns a larger business operation.
// It intentionally does not send notifications or trigger achievements; those
// side effects must happen after the caller commits its transaction.
func SendInTransaction(
	tx GiftTx,
	fromUserID, toUserID, giftID uint,
	quantity int,
	description string,
) (model.GiftRecord, model.Gift, error) {
	if tx == nil || fromUserID == 0 || toUserID == 0 || giftID == 0 || quantity <= 0 {
		return model.GiftRecord{}, model.Gift{}, ErrInvalidGiftRequest
	}

	gift, err := tx.GetGift(giftID)
	if err != nil {
		return model.GiftRecord{}, model.Gift{}, err
	}
	sender, err := tx.GetUserForUpdate(fromUserID)
	if err != nil {
		return model.GiftRecord{}, model.Gift{}, err
	}
	if _, err := tx.GetUserForUpdate(toUserID); err != nil {
		return model.GiftRecord{}, model.Gift{}, err
	}

	cost := float64(gift.Price * quantity)
	stock, stockErr := tx.FindUserGiftStock(fromUserID, giftID)
	if stockErr == nil && stock.Quantity >= quantity {
		if err := tx.UpdateUserGiftStockQuantity(&stock, stock.Quantity-quantity); err != nil {
			return model.GiftRecord{}, model.Gift{}, err
		}
	} else {
		if sender.Balance < cost {
			return model.GiftRecord{}, model.Gift{}, ErrInsufficientBal
		}
		if err := tx.DeductBalance(fromUserID, cost); err != nil {
			return model.GiftRecord{}, model.Gift{}, err
		}
		if err := tx.CreateTransaction(&model.Transaction{
			UserID: fromUserID, Amount: cost, Type: "consume", Status: "success", Description: description,
		}); err != nil {
			return model.GiftRecord{}, model.Gift{}, err
		}
	}

	record := model.GiftRecord{FromUserID: fromUserID, ToUserID: toUserID, GiftID: giftID, Quantity: quantity}
	if err := tx.CreateGiftRecord(&record); err != nil {
		return model.GiftRecord{}, model.Gift{}, err
	}
	if err := tx.UpdateReceiverGiftStats(toUserID, gift.Price*quantity, cost); err != nil {
		return model.GiftRecord{}, model.Gift{}, err
	}
	return record, gift, nil
}
