package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapMenusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapMenusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapMenusLogic {
	return &AdminBootstrapMenusLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminBootstrapMenusLogic) AdminBootstrapMenus(_ *super.AdminBootstrapMenusReq) (*super.AdminBootstrapMenusResp, error) {
	created, err := utils.BootstrapAdminMenus(l.svcCtx.DB)
	if err != nil {
		l.Errorf("[admin] bootstrap menus: %v", err)
		return nil, errorx.Internal("初始化菜单失败")
	}
	return &super.AdminBootstrapMenusResp{Created: created}, nil
}
