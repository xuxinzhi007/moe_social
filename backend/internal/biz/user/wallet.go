package userbiz

import (
	"context"
	"errors"
	"strconv"

	userv1 "backend/api/user/v1"
	"backend/model"

	"gorm.io/gorm"
)

// GetTransactions 分页查询用户交易记录。
func GetTransactions(ctx context.Context, store UserStore, in *userv1.GetTransactionsReq) (*userv1.GetTransactionsResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	if _, err := store.GetUserByID(ctx, uint(userID)); err != nil {
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
	offset := int((page - 1) * pageSize)

	total, err := store.CountTransactions(ctx, userID)
	if err != nil {
		return nil, err
	}
	transactions, err := store.ListTransactions(ctx, userID, offset, int(pageSize))
	if err != nil {
		return nil, err
	}

	rpcTx := make([]*userv1.Transaction, len(transactions))
	for i, t := range transactions {
		rpcTx[i] = transactionToV1(&t)
	}
	return &userv1.GetTransactionsResp{Transactions: rpcTx, Total: int32(total)}, nil
}

// GetTransaction 按 ID 查询单笔交易。
func GetTransaction(ctx context.Context, store UserStore, in *userv1.GetTransactionReq) (*userv1.GetTransactionResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.Atoi(in.GetId())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	transaction, err := store.GetTransactionByID(ctx, id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrTransactionNotFound
		}
		return nil, err
	}
	return &userv1.GetTransactionResp{Transaction: transactionToV1(&transaction)}, nil
}

// Recharge 钱包充值（事务）。
func Recharge(ctx context.Context, store UserStore, in *userv1.RechargeReq) (*userv1.RechargeResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
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
	tx, err := store.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()

	user, err := tx.GetUserForUpdate(uint(userID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	amount := float64(in.GetAmount())
	newBalance = user.Balance + amount
	if newBalance < 0 {
		return nil, ErrInsufficientBalance
	}
	if err := tx.UpdateUserBalance(user.ID, newBalance); err != nil {
		return nil, err
	}
	transaction := model.Transaction{
		UserID:      uint(userID),
		Amount:      amount,
		Type:        "recharge",
		Status:      "success",
		Description: in.GetDescription(),
	}
	if err := tx.CreateTransaction(&transaction); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return &userv1.RechargeResp{Message: "充值成功", NewBalance: float32(newBalance)}, nil
}

func transactionToV1(t *model.Transaction) *userv1.Transaction {
	if t == nil {
		return nil
	}
	return &userv1.Transaction{
		Id:          strconv.Itoa(int(t.ID)),
		UserId:      strconv.Itoa(int(t.UserID)),
		Amount:      float32(t.Amount),
		Type:        t.Type,
		Status:      t.Status,
		Description: t.Description,
		CreatedAt:   t.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}
