package vip

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlansLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlansLogic {
	return &GetVipPlansLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetVipPlansLogic) GetVipPlans(req *types.EmptyReq) (resp *types.GetVipPlansResp, err error) {
	// 调用RPC服务获取VIP套餐列表
	rpcResp, err := l.svcCtx.SuperRpcClient.GetVipPlans(l.ctx, &super.GetVipPlansReq{})
	if err != nil {
		return &types.GetVipPlansResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
		}, nil
	}

	// 转换为API响应格式
	respPlans := make([]types.VipPlan, 0, len(rpcResp.Plans))
	for _, plan := range rpcResp.Plans {
		respPlans = append(respPlans, types.VipPlan{
			Id:           plan.Id,
			Name:         plan.Name,
			Description:  plan.Description,
			Price:        float64(plan.Price),
			DurationDays: int(plan.DurationDays),
			CreatedAt:    plan.CreatedAt,
			UpdatedAt:    plan.UpdatedAt,
		})
	}

	return &types.GetVipPlansResp{
		BaseResp: common.HandleRPCError(nil, "获取VIP套餐列表成功"),
		Data:     respPlans,
	}, nil
}
