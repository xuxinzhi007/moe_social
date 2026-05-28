package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListVipPlansLogic {
	return &AdminListVipPlansLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListVipPlansLogic) AdminListVipPlans(in *moe.AdminListVipPlansReq) (*moe.AdminListVipPlansResp, error) {
	resp, err := newVipAdminApp(l.svcCtx.DB).AdminListVipPlans(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] list vip plans: %v", err)
		return nil, mapVipBizErr(err)
	}
	return resp, nil
}
