// Package userapp 钱包与交易。
package userapp

import (
	"context"
	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
)

// Package userapp 钱包与交易。

func (s *AppService) GetTransactions(ctx context.Context, in *userv1.GetTransactionsReq) (*userv1.GetTransactionsResp, error) {
	return userbiz.GetTransactions(ctx, s.store, in)
}

func (s *AppService) GetTransaction(ctx context.Context, in *userv1.GetTransactionReq) (*userv1.GetTransactionResp, error) {
	return userbiz.GetTransaction(ctx, s.store, in)
}

func (s *AppService) Recharge(ctx context.Context, in *userv1.RechargeReq) (*userv1.RechargeResp, error) {
	return userbiz.Recharge(ctx, s.store, in)
}
