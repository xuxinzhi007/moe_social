package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type GetTransactionLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetTransactionLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetTransactionLogic {
	return &GetTransactionLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetTransactionLogic) GetTransaction(in *super.GetTransactionReq) (*super.GetTransactionResp, error) {
	// 1. 转换交易ID
	id, err := strconv.Atoi(in.Id)
	if err != nil {
		return nil, errorx.New(400, "无效的交易记录ID")
	}

	// 2. 查询交易记录
	var transaction model.Transaction
	if err := l.svcCtx.DB.First(&transaction, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "交易记录不存在")
		}
		return nil, errorx.New(500, "查询交易记录失败")
	}

	// 3. 转换为RPC响应格式
    rpcTransaction := &super.Transaction{
        Id:          strconv.Itoa(int(transaction.ID)),
        UserId:      strconv.Itoa(int(transaction.UserID)),
        Amount:      float32(transaction.Amount),
        Type:        transaction.Type,
        Status:      transaction.Status,
        Description: transaction.Description,
        CreatedAt:   transaction.CreatedAt.Format("2006-01-02 15:04:05"),
    }

	// 4. 构建响应
	return &super.GetTransactionResp{
		Transaction: rpcTransaction,
	}, nil
}
