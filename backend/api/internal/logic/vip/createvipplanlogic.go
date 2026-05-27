package vip

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	vipbiz "backend/internal/biz/vip"

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
	plan, err := l.svcCtx.VipGW.CreatePlan(l.ctx, vipbiz.CreatePlanInput{
		Name:         req.Name,
		Description:  req.Description,
		Price:        req.Price,
		DurationDays: req.DurationDays,
	})
	if err != nil {
		return &types.CreateVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
		}, nil
	}

	return &types.CreateVipPlanResp{
		BaseResp: common.HandleRPCError(nil, "创建VIP套餐成功"),
		Data:     common.VipPlanModelToTypes(plan),
	}, nil
}
