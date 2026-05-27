package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlanLogic {
	return &GetVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetVipPlanLogic) GetVipPlan(in *super.GetVipPlanReq) (*super.GetVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := vipbiz.GetPlan(l.ctx, l.svcCtx.DB, planID)
	if err != nil {
		l.Errorf("get vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &super.GetVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
