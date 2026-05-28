package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlansLogic {
	return &GetVipPlansLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetVipPlansLogic) GetVipPlans(in *moe.GetVipPlansReq) (*moe.GetVipPlansResp, error) {
	_ = in
	plans, err := vipbiz.ListAllPlans(l.ctx, l.svcCtx.DB)
	if err != nil {
		l.Errorf("get vip plans: %v", err)
		return nil, mapVipBizErr(err)
	}
	respPlans := make([]*moe.VipPlan, len(plans))
	for i, plan := range plans {
		respPlans[i] = vipPlanModelToProto(plan)
	}
	return &moe.GetVipPlansResp{Plans: respPlans}, nil
}
