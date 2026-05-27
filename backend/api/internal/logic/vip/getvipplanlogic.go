package vip

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

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
	plan, err := l.svcCtx.VipGW.GetPlan(l.ctx, req.PlanId)
	if err != nil {
		return &types.GetVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
		}, nil
	}

	return &types.GetVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "获取VIP套餐成功"),
		Data:     common.VipPlanModelToTypes(plan),
	}, nil
}
