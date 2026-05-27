package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteVipPlanLogic {
	return &AdminDeleteVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDeleteVipPlanLogic) AdminDeleteVipPlan(in *super.AdminDeleteVipPlanReq) (*super.AdminDeleteVipPlanResp, error) {
	planID, err := parseVipPlanID(in.GetPlanId())
	if err != nil {
		return nil, err
	}
	if err := vipbiz.DeletePlan(l.ctx, l.svcCtx.DB, planID); err != nil {
		l.Errorf("[admin] delete vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &super.AdminDeleteVipPlanResp{}, nil
}
