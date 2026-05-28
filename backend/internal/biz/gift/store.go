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
