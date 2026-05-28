package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetTransactionsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetTransactionsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetTransactionsLogic {
	return &GetTransactionsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetTransactionsLogic) GetTransactions(in *moe.GetTransactionsReq) (*moe.GetTransactionsResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).GetTransactions(l.ctx, in)
	return resp, mapUserBizErr(err)
}
