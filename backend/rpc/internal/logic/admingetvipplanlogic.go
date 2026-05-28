package logic

import (
	"context"

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
	return &AdminGetVipPlanLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetVipPlanLogic) AdminGetVipPlan(in *super.AdminGetVipPlanReq) (*super.AdminGetVipPlanResp, error) {
	resp, err := newVipAdminApp(l.svcCtx.DB).AdminGetVipPlan(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] get vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return resp, nil
}
