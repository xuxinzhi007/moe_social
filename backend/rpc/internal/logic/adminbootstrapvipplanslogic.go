package logic

import (
	"context"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapVipPlansLogic {
	return &AdminBootstrapVipPlansLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminBootstrapVipPlansLogic) AdminBootstrapVipPlans(in *super.AdminBootstrapVipPlansReq) (*super.AdminBootstrapVipPlansResp, error) {
	_ = in
	created, err := vipbiz.BootstrapPlans(l.ctx, l.svcCtx.DB)
	if err != nil {
		l.Errorf("[admin] bootstrap vip plans: %v", err)
		return nil, mapVipBizErr(err)
	}
	return &super.AdminBootstrapVipPlansResp{
		Created: int32(created),
	}, nil
}
