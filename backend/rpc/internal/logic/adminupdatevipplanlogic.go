package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateVipPlanLogic {
	return &AdminUpdateVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminUpdateVipPlanLogic) AdminUpdateVipPlan(in *super.AdminUpdateVipPlanReq) (*super.AdminUpdateVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	plan, err := vipbiz.UpdatePlan(l.ctx, l.svcCtx.DB, planID, vipbiz.UpdatePlanPatch{
		UpdateName:         in.GetUpdateName(),
		Name:               in.GetName(),
		UpdateDescription:  in.GetUpdateDescription(),
		Description:        in.GetDescription(),
		UpdatePrice:        in.GetUpdatePrice(),
		Price:              float64(in.GetPrice()),
		UpdateDurationDays: in.GetUpdateDurationDays(),
		DurationDays:       int(in.GetDurationDays()),
	})
	if err != nil {
		l.Errorf("[admin] update vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &super.AdminUpdateVipPlanResp{
		Plan: vipPlanModelToProto(plan),
	}, nil
}
