package userhttp

import (
	"context"

	userv1 "backend/api/user/v1"
)

func (s *Server) GetTransaction(ctx context.Context, in *userv1.GetTransactionReq) (*userv1.GetTransactionResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetTransaction(ctx, in)
}

func (s *Server) GetTransactions(ctx context.Context, in *userv1.GetTransactionsReq) (*userv1.GetTransactionsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetTransactions(ctx, in)
}

func (s *Server) Recharge(ctx context.Context, in *userv1.RechargeReq) (*userv1.RechargeResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Recharge(ctx, in)
}
