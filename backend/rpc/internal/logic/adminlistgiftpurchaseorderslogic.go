package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGiftPurchaseOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListGiftPurchaseOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGiftPurchaseOrdersLogic {
	return &AdminListGiftPurchaseOrdersLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListGiftPurchaseOrdersLogic) AdminListGiftPurchaseOrders(in *super.AdminListGiftPurchaseOrdersReq) (*super.AdminListGiftPurchaseOrdersResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListGiftPurchaseOrders(l.ctx, in)
	if err != nil {
		return nil, mapAdminOrdersErr(err)
	}
	return resp, nil
}
