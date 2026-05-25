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

type AdminUpdateVipPlanLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateVipPlanLogic {
	return &AdminUpdateVipPlanLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateVipPlanLogic) AdminUpdateVipPlan(req *types.AdminUpdateVipPlanReq) (*types.AdminUpdateVipPlanResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpdateVipPlan(l.ctx, &super.AdminUpdateVipPlanReq{
		PlanId:             req.PlanId,
		Name:               req.Name,
		Description:        req.Description,
		Price:              float32(req.Price),
		DurationDays:       int32(req.DurationDays),
		UpdateName:         req.UpdateName,
		UpdateDescription:  req.UpdateDescription,
		UpdatePrice:        req.UpdatePrice,
		UpdateDurationDays: req.UpdateDurationDays,
	})
	if err != nil {
		return &types.AdminUpdateVipPlanResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	resp := &types.AdminUpdateVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "更新成功"),
		Data:     common.RpcVipPlanToTypes(rpcResp.GetPlan()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "vip_plan", req.PlanId, "更新 VIP 套餐")
	}
	return resp, nil
}
