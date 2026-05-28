package logic

import (
	"context"

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
	resp, err := newVipAdminApp(l.svcCtx.DB).AdminUpdateVipPlan(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] update vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return resp, nil
}
