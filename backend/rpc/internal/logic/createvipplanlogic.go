package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipPlanLogic {
	return &CreateVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateVipPlanLogic) CreateVipPlan(in *moe.CreateVipPlanReq) (*moe.CreateVipPlanResp, error) {
	plan, err := vipbiz.CreatePlan(l.ctx, l.svcCtx.VipStore(), vipbiz.CreatePlanInput{
		Name:         in.GetName(),
		Description:  in.GetDescription(),
		Price:        float64(in.GetPrice()),
		DurationDays: int(in.GetDurationDays()),
	})
	if err != nil {
		l.Errorf("create vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &moe.CreateVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
