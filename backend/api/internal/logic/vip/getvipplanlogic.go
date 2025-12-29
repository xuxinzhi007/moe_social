package vip

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlanLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlanLogic {
	return &GetVipPlanLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetVipPlanLogic) GetVipPlan(req *types.GetVipPlanReq) (resp *types.GetVipPlanResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.GetVipPlan(l.ctx, &super.GetVipPlanReq{
		PlanId: req.PlanId,
	})
	if err != nil {
		l.Errorf("调用RPC服务失败: %v", err)
		return &types.GetVipPlanResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	return &types.GetVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "获取VIP套餐成功"),
		Data: types.VipPlan{
			Id:           rpcResp.Plan.Id,
			Name:         rpcResp.Plan.Name,
			Description:  rpcResp.Plan.Description,
			Price:        float64(rpcResp.Plan.Price),
			DurationDays: int(rpcResp.Plan.DurationDays),
			CreatedAt:    rpcResp.Plan.CreatedAt,
			UpdatedAt:    rpcResp.Plan.UpdatedAt,
		},
	}, nil
}
