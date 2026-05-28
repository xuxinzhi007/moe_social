package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListVipOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListVipOrdersLogic {
	return &AdminListVipOrdersLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListVipOrdersLogic) AdminListVipOrders(in *super.AdminListVipOrdersReq) (*super.AdminListVipOrdersResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListVipOrders(l.ctx, in)
	if err != nil {
		return nil, mapAdminOrdersErr(err)
	}
	return resp, nil
}
