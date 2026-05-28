package logic

import (
	"context"

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
	resp, err := newVipAdminApp(l.svcCtx.DB).AdminBootstrapVipPlans(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] bootstrap vip plans: %v", err)
		return nil, mapVipBizErr(err)
	}
	return resp, nil
}
