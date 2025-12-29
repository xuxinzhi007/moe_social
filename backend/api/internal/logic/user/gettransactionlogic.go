package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetTransactionLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetTransactionLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetTransactionLogic {
	return &GetTransactionLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetTransactionLogic) GetTransaction(req *types.GetTransactionReq) (resp *types.GetTransactionResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetTransaction(l.ctx, &super.GetTransactionReq{
		Id: req.TransactionId,
	})
	if err != nil {
		return nil, err
	}

	t := rpcResp.Transaction
	return &types.GetTransactionResp{
		BaseResp: types.BaseResp{
			Code:    200,
			Message: "获取交易详情成功",
			Success: true,
		},
		Data: types.Transaction{
			Id:          t.Id,
			UserId:      t.UserId,
			Type:        t.Type,
			Amount:      float64(t.Amount),
			Description: t.Description,
			Status:      t.Status,
			CreatedAt:   t.CreatedAt,
		},
	}, nil
}
