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
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminGetVipPlan(l.ctx, &super.AdminGetVipPlanReq{
		PlanId: req.PlanId,
	})
	if err != nil {
		return &types.AdminGetVipPlanResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.AdminGetVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcVipPlanToTypes(rpcResp.GetPlan()),
	}, nil
}
