package logic

import (
	"context"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapAccountLogic {
	return &AdminBootstrapAccountLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminBootstrapAccountLogic) AdminBootstrapAccount(in *moe.AdminBootstrapAccountReq) (*moe.AdminBootstrapAccountResp, error) {
	return adminbiz.BootstrapAdminAccount(l.ctx, l.svcCtx.AdminStore(), in)
}
