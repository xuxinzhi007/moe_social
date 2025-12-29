package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetTransactionsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetTransactionsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetTransactionsLogic {
	return &GetTransactionsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetTransactionsLogic) GetTransactions(req *types.GetTransactionsReq) (resp *types.GetTransactionsResp, err error) {
	// 调用RPC接口
	rpcResp, err := l.svcCtx.SuperRpcClient.GetTransactions(l.ctx, &super.GetTransactionsReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return nil, err
	}

	// 转换响应
	transactions := make([]types.Transaction, 0)
	for _, t := range rpcResp.Transactions {
		transactions = append(transactions, types.Transaction{
			Id:          t.Id,
			UserId:      t.UserId,
			Type:        t.Type,
			Amount:      float64(t.Amount),
			Description: t.Description,
			Status:      t.Status,
			CreatedAt:   t.CreatedAt,
		})
	}

	return &types.GetTransactionsResp{
		BaseResp: types.BaseResp{
			Code:    200,
			Message: "获取交易记录成功",
			Success: true,
		},
		Data:  transactions,
		Total: int(rpcResp.Total),
	}, nil
}
