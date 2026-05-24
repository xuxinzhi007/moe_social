package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

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

func (l *AdminBootstrapAccountLogic) AdminBootstrapAccount(in *super.AdminBootstrapAccountReq) (*super.AdminBootstrapAccountResp, error) {
	_ = in
	created := utils.BootstrapAdminAccount(l.svcCtx.DB)
	return &super.AdminBootstrapAccountResp{Created: created}, nil
}
