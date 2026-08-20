package giftdata

import (
	"context"

	giftbiz "backend/internal/biz/gift"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.GiftStore（P4-D）。
func NewStore(db *gorm.DB) giftbiz.GiftStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

// NewTransaction exposes the existing GiftTx implementation to a composed
// cross-domain transaction without starting a nested database transaction.
func NewTransaction(tx *gorm.DB) giftbiz.GiftTx {
	if tx == nil {
		return nil
	}
	return &giftTx{tx: tx}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) giftbiz.GiftStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) CountGifts(ctx context.Context) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.Gift{}).Count(&total).Error
	return total, err
}

func (s *store) ListGifts(ctx context.Context, offset, limit int) ([]model.Gift, error) {
	var gifts []model.Gift
	err := s.db.WithContext(ctx).Order("sort_order ASC, price ASC, id ASC").
		Offset(offset).Limit(limit).Find(&gifts).Error
	return gifts, err
}

func (s *store) FindUserGiftStock(ctx context.Context, userID uint, giftIDs []uint) ([]model.UserGiftStock, error) {
	if len(giftIDs) == 0 {
		return nil, nil
	}
	var rows []model.UserGiftStock
	err := s.db.WithContext(ctx).Where("user_id = ? AND gift_id IN ?", userID, giftIDs).Find(&rows).Error
	return rows, err
}

func (s *store) GetGiftByID(ctx context.Context, id uint) (model.Gift, error) {
	var gift model.Gift
	err := s.db.WithContext(ctx).First(&gift, id).Error
	return gift, err
}

func (s *store) CountGiftRecords(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.GiftRecord{}).
		Where("from_user_id = ? OR to_user_id = ?", userID, userID).Count(&total).Error
	return total, err
}

func (s *store) ListGiftRecords(ctx context.Context, userID uint, offset, limit int) ([]model.GiftRecord, error) {
	var rows []model.GiftRecord
	err := s.db.WithContext(ctx).Where("from_user_id = ? OR to_user_id = ?", userID, userID).
		Preload("Gift").Order("created_at DESC").Offset(offset).Limit(limit).Find(&rows).Error
	return rows, err
}

func (s *store) UserExists(ctx context.Context, userID uint) error {
	return s.db.WithContext(ctx).First(&model.User{}, userID).Error
}

func (s *store) CountPurchaseOrders(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.GiftPurchaseOrder{}).
		Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *store) ListPurchaseOrders(ctx context.Context, userID uint, offset, limit int) ([]model.GiftPurchaseOrder, error) {
	var rows []model.GiftPurchaseOrder
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC").Offset(offset).Limit(limit).Find(&rows).Error
	return rows, err
}

func (s *store) GetUserByID(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *store) Transaction(ctx context.Context, fn func(giftbiz.GiftTx) error) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return fn(&giftTx{tx: tx})
	})
}

type giftTx struct {
	tx *gorm.DB
}

func (t *giftTx) GetGift(id uint) (model.Gift, error) {
	var gift model.Gift
	err := t.tx.First(&gift, id).Error
	return gift, err
}

func (t *giftTx) GetUser(id uint) (model.User, error) {
	var user model.User
	err := t.tx.First(&user, id).Error
	return user, err
}

func (t *giftTx) GetUserForUpdate(id uint) (model.User, error) {
	var user model.User
	err := t.tx.Set("gorm:query_option", "FOR UPDATE").First(&user, id).Error
	return user, err
}

func (t *giftTx) DeductBalance(userID uint, cost float64) error {
	res := t.tx.Model(&model.User{}).Where("id = ? AND balance >= ?", userID, cost).
		Update("balance", gorm.Expr("balance - ?", cost))
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected != 1 {
		return giftbiz.ErrInsufficientBal
	}
	return nil
}

func (t *giftTx) FindUserGiftStock(userID, giftID uint) (model.UserGiftStock, error) {
	var stock model.UserGiftStock
	err := t.tx.Where("user_id = ? AND gift_id = ?", userID, giftID).First(&stock).Error
	return stock, err
}

func (t *giftTx) CreateUserGiftStock(stock *model.UserGiftStock) error {
	return t.tx.Create(stock).Error
}

func (t *giftTx) SaveUserGiftStock(stock *model.UserGiftStock) error {
	return t.tx.Save(stock).Error
}

func (t *giftTx) UpdateUserGiftStockQuantity(stock *model.UserGiftStock, quantity int) error {
	return t.tx.Model(stock).Update("quantity", quantity).Error
}

func (t *giftTx) CreatePurchaseOrder(order *model.GiftPurchaseOrder) error {
	return t.tx.Create(order).Error
}

func (t *giftTx) CreateTransaction(tr *model.Transaction) error {
	return t.tx.Create(tr).Error
}

func (t *giftTx) CreateGiftRecord(record *model.GiftRecord) error {
	return t.tx.Create(record).Error
}

func (t *giftTx) UpdateReceiverGiftStats(toUserID uint, addCharm int, addValue float64) error {
	return t.tx.Model(&model.User{}).Where("id = ?", toUserID).Updates(map[string]interface{}{
		"gift_charm":          gorm.Expr("gift_charm + ?", addCharm),
		"received_gift_value": gorm.Expr("received_gift_value + ?", addValue),
	}).Error
}

// Ensure giftTx implements GiftTx at compile time.
var _ giftbiz.GiftTx = (*giftTx)(nil)
