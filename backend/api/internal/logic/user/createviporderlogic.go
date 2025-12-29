package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipOrderLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCreateVipOrderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipOrderLogic {
	return &CreateVipOrderLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateVipOrderLogic) CreateVipOrder(req *types.CreateVipOrderReq) (resp *types.CreateVipOrderResp, err error) {
	// 调用RPC服务创建VIP订单
	rpcResp, err := l.svcCtx.SuperRpcClient.CreateVipOrder(l.ctx, &super.CreateVipOrderReq{
		UserId: req.UserId,
		PlanId: req.PlanId,
	})
	if err != nil {
		return &types.CreateVipOrderResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.CreateVipOrderResp{
		BaseResp: common.HandleRPCError(nil, "创建VIP订单成功"),
		Data: types.VipOrder{
			Id:        rpcResp.Order.Id,
			UserId:    rpcResp.Order.UserId,
			PlanId:    rpcResp.Order.PlanId,
			PlanName:  rpcResp.Order.PlanName,
			Amount:    float64(rpcResp.Order.Amount),
			Status:    rpcResp.Order.Status,
			CreatedAt: rpcResp.Order.CreatedAt,
			PaidAt:    rpcResp.Order.PaidAt,
		},
	}, nil
}
