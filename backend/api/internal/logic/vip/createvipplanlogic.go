package vip

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipPlanLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCreateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipPlanLogic {
	return &CreateVipPlanLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateVipPlanLogic) CreateVipPlan(req *types.CreateVipPlanReq) (resp *types.CreateVipPlanResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.CreateVipPlan(l.ctx, &rpc.CreateVipPlanReq{
		Name:         req.Name,
		Description:  req.Description,
		Price:        float32(req.Price),
		DurationDays: int32(req.DurationDays),
	})
	if err != nil {
		l.Errorf("调用RPC服务失败: %v", err)
		return &types.CreateVipPlanResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	return &types.CreateVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "创建VIP套餐成功"),
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
