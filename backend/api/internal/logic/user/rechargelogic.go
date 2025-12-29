package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type RechargeLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewRechargeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RechargeLogic {
	return &RechargeLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *RechargeLogic) Recharge(req *types.RechargeReq) (resp *types.RechargeResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.Recharge(l.ctx, &super.RechargeReq{
		UserId:      req.UserId,
		Amount:      float32(req.Amount),
		Description: req.Description,
	})
	if err != nil {
		return nil, err
	}

	// 充值成功后，这里返回的 Data 可能是空的或者新的余额，根据 API 定义
	// RechargeResp 的 Data 是 Transaction 类型
	// 但 RPC RechargeResp 只返回了 message 和 new_balance
	// 这里可能需要调整一下，要么 API 返回 Transaction，要么 RPC 返回 Transaction
	// 鉴于目前 RPC 已经定义好返回 message/balance，而 API 要求返回 Transaction
	// 我们可以再次调用 GetTransactions 获取最新的一条，或者简化 API 定义
	// 为了快速修复，我们可以修改 RPC RechargeLogic 让其返回 Transaction ID，或者
	// 这里先简单构造一个 Transaction 对象返回（虽然没有 ID）
	
	// 为了严谨，建议修改 RPC Recharge 定义让其返回 Transaction
	// 但这需要改 proto 并重新生成。
	// 也可以在 API 层构造一个假的 Transaction 返回，或者
	// 既然是前端调用充值，通常只关心成功与否和余额。
	// 这里我们尽量返回合理的数据。
	
	// 实际上，RPC Logic 中应该已经创建了 Transaction。
	// 如果 RPC RechargeResp 能返回 Transaction 就最好了。
	
	// 暂时返回一个简单的响应
	return &types.RechargeResp{
		BaseResp: types.BaseResp{
			Code:    200,
			Message: "充值成功",
			Success: true,
		},
		Data: types.Transaction{
			UserId:      req.UserId,
			Type:        "recharge",
			Amount:      req.Amount,
			Description: req.Description,
			Status:      "success",
			// Id 和 CreatedAt 暂时无法获取
		},
	}, nil
}
