package userbiz

import (
	"context"
	"errors"
	"strconv"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// GetTransactions 分页查询用户交易记录。
func GetTransactions(ctx context.Context, db *gorm.DB, in *moe.GetTransactionsReq) (*moe.GetTransactionsResp, error) {
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	var user model.User
	if err := db.WithContext(ctx).First(&user, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (page - 1) * pageSize

	var total int64
	if err := db.WithContext(ctx).Model(&model.Transaction{}).Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, err
	}
	var transactions []model.Transaction
	if err := db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC").Offset(int(offset)).Limit(int(pageSize)).
		Find(&transactions).Error; err != nil {
		return nil, err
	}

	rpcTx := make([]*moe.Transaction, len(transactions))
	for i, t := range transactions {
		rpcTx[i] = transactionToProto(&t)
	}
	return &moe.GetTransactionsResp{Transactions: rpcTx, Total: int32(total)}, nil
}

// GetTransaction 按 ID 查询单笔交易。
func GetTransaction(ctx context.Context, db *gorm.DB, in *moe.GetTransactionReq) (*moe.GetTransactionResp, error) {
	id, err := strconv.Atoi(in.GetId())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	var transaction model.Transaction
	if err := db.WithContext(ctx).First(&transaction, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrTransactionNotFound
		}
		return nil, err
	}
	return &moe.GetTransactionResp{Transaction: transactionToProto(&transaction)}, nil
}

// Recharge 钱包充值（事务）。
func Recharge(ctx context.Context, db *gorm.DB, in *moe.RechargeReq) (*moe.RechargeResp, error) {
	if in.GetUserId() == "" {
		return nil, ErrInvalidArgument
	}
	if in.GetAmount() == 0 {
		return nil, ErrInvalidArgument
	}
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 32)
	if err != nil {
		return nil, ErrInvalidArgument
	}

	var newBalance float64
	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var user model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&user, uint(userID)).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrNotFound
			}
			return err
		}
		amount := float64(in.GetAmount())
		newBalance = user.Balance + amount
		if newBalance < 0 {
			return ErrInsufficientBalance
		}
		if err := tx.Model(&user).UpdateColumn("balance", newBalance).Error; err != nil {
			return err
		}
		transaction := model.Transaction{
			UserID:      uint(userID),
			Amount:      amount,
			Type:        "recharge",
			Status:      "success",
			Description: in.GetDescription(),
		}
		return tx.Create(&transaction).Error
	})
	if err != nil {
		return nil, err
	}
	return &moe.RechargeResp{Message: "充值成功", NewBalance: float32(newBalance)}, nil
}

func transactionToProto(t *model.Transaction) *moe.Transaction {
	if t == nil {
		return nil
	}
	return &moe.Transaction{
		Id:          strconv.Itoa(int(t.ID)),
		UserId:      strconv.Itoa(int(t.UserID)),
		Amount:      float32(t.Amount),
		Type:        t.Type,
		Status:      t.Status,
		Description: t.Description,
		CreatedAt:   t.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}
