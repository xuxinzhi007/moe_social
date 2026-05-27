package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetVipPlanLogic {
	return &AdminGetVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminGetVipPlanLogic) AdminGetVipPlan(in *super.AdminGetVipPlanReq) (*super.AdminGetVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := vipbiz.GetPlan(l.ctx, l.svcCtx.DB, planID)
	if err != nil {
		l.Errorf("[admin] get vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &super.AdminGetVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
