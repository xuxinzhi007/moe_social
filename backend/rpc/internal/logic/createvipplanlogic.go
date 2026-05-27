package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *CreateVipPlanLogic) CreateVipPlan(in *super.CreateVipPlanReq) (*super.CreateVipPlanResp, error) {
	plan, err := vipbiz.CreatePlan(l.ctx, l.svcCtx.DB, vipbiz.CreatePlanInput{
		Name:         in.GetName(),
		Description:  in.GetDescription(),
		Price:        float64(in.GetPrice()),
		DurationDays: int(in.GetDurationDays()),
	})
	if err != nil {
		l.Errorf("create vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &super.CreateVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
