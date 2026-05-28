package logic

import (
	"context"

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
	resp, err := newVipAdminApp(l.svcCtx.DB).AdminDeleteVipPlan(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] delete vip plan: %v", err)
		return nil, mapVipBizErr(err)
	}
	return resp, nil
}
