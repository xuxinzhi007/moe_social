package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMenusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListMenusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMenusLogic {
	return &AdminListMenusLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListMenusLogic) AdminListMenus(in *super.AdminListMenusReq) (*super.AdminListMenusResp, error) {
	return adminapp.New(l.svcCtx.DB).ListMenus(l.ctx, in)
}
