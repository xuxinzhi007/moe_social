package vip

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

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

func (l *GetVipPlansLogic) GetVipPlans(_ *types.EmptyReq) (resp *types.GetVipPlansResp, err error) {
	rows, err := l.svcCtx.VipGW.ListAllPlans(l.ctx)
	if err != nil {
		return &types.GetVipPlansResp{
			BaseResp: common.HandleVipGWError(err, ""),
			Data:     nil,
		}, nil
	}

	respPlans := make([]types.VipPlan, 0, len(rows))
	for _, plan := range rows {
		respPlans = append(respPlans, common.VipPlanModelToTypes(plan))
	}

	return &types.GetVipPlansResp{
		BaseResp: common.HandleRPCError(nil, "获取VIP套餐列表成功"),
		Data:     respPlans,
	}, nil
}
