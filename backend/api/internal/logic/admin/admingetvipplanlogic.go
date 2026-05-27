// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetVipPlanLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetVipPlanLogic {
	return &AdminGetVipPlanLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetVipPlanLogic) AdminGetVipPlan(req *types.AdminGetVipPlanReq) (resp *types.AdminGetVipPlanResp, err error) {
	plan, err := l.svcCtx.VipGW.GetPlan(l.ctx, req.PlanId)
	if err != nil {
		return &types.AdminGetVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
		}, nil
	}

	return &types.AdminGetVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.VipPlanModelToTypes(plan),
	}, nil
}
