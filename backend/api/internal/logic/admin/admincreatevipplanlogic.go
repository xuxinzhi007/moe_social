// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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

	rpcResp, err := l.svcCtx.SuperRpcClient.CreateVipPlan(l.ctx, &super.CreateVipPlanReq{
		Name:         strings.TrimSpace(req.Name),
		Description:  strings.TrimSpace(req.Description),
		Price:        float32(req.Price),
		DurationDays: int32(req.DurationDays),
	})
	if err != nil {
		return &types.AdminCreateVipPlanResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	resp = &types.AdminCreateVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.RpcVipPlanToTypes(rpcResp.GetPlan()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "create", "vip_plan", resp.Data.Id, "创建 VIP 套餐")
	}
	return resp, nil
}
