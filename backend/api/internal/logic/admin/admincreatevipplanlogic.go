// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	vipbiz "backend/internal/biz/vip"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateVipPlanLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCreateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateVipPlanLogic {
	return &AdminCreateVipPlanLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminCreateVipPlanLogic) AdminCreateVipPlan(req *types.AdminCreateVipPlanReq) (resp *types.AdminCreateVipPlanResp, err error) {
	if strings.TrimSpace(req.Name) == "" {
		return &types.AdminCreateVipPlanResp{
			BaseResp: types.BaseResp{Success: false, Message: "套餐名称不能为空"},
		}, nil
	}
	if req.DurationDays <= 0 {
		return &types.AdminCreateVipPlanResp{
			BaseResp: types.BaseResp{Success: false, Message: "有效期天数必须大于 0"},
		}, nil
	}
	if req.Price < 0 {
		return &types.AdminCreateVipPlanResp{
			BaseResp: types.BaseResp{Success: false, Message: "价格不能为负数"},
		}, nil
	}

	plan, err := l.svcCtx.VipGW.CreatePlan(l.ctx, vipbiz.CreatePlanInput{
		Name:         strings.TrimSpace(req.Name),
		Description:  strings.TrimSpace(req.Description),
		Price:        req.Price,
		DurationDays: req.DurationDays,
	})
	if err != nil {
		return &types.AdminCreateVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
		}, nil
	}

	resp = &types.AdminCreateVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.VipPlanModelToTypes(plan),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "create", "vip_plan", resp.Data.Id, "创建 VIP 套餐")
	}
	return resp, nil
}
