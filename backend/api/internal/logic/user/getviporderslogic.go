package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipOrdersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipOrdersLogic {
	return &GetVipOrdersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetVipOrdersLogic) GetVipOrders(req *types.GetVipOrdersReq) (resp *types.GetVipOrdersResp, err error) {
	// 调用RPC服务获取VIP订单列表
	rpcResp, err := l.svcCtx.SuperRpcClient.GetVipOrders(l.ctx, &rpc.GetVipOrdersReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetVipOrdersResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
			Total:    0,
		}, nil
	}

	// 转换为API响应格式
	respOrders := make([]types.VipOrder, 0, len(rpcResp.Orders))
	for _, order := range rpcResp.Orders {
		respOrders = append(respOrders, types.VipOrder{
			Id:        order.Id,
			UserId:    order.UserId,
			PlanId:    order.PlanId,
			PlanName:  order.PlanName,
			Amount:    float64(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt,
			PaidAt:    order.PaidAt,
		})
	}

	return &types.GetVipOrdersResp{
		BaseResp: common.HandleRPCError(nil, "获取VIP订单列表成功"),
		Data:     respOrders,
		Total:    int(rpcResp.Total),
	}, nil
}
