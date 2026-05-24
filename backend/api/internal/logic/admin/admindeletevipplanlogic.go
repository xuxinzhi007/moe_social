// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteVipPlanLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteVipPlanLogic {
	return &AdminDeleteVipPlanLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeleteVipPlanLogic) AdminDeleteVipPlan(req *types.AdminDeleteVipPlanReq) (resp *types.AdminDeleteVipPlanResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.AdminDeleteVipPlan(l.ctx, &super.AdminDeleteVipPlanReq{
		PlanId: req.PlanId,
	})
	if err != nil {
		return &types.AdminDeleteVipPlanResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.AdminDeleteVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "已删除"),
	}, nil
}
