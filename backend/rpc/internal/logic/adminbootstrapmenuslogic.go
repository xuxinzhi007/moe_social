package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

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

func (l *AdminBootstrapMenusLogic) AdminBootstrapMenus(in *moe.AdminBootstrapMenusReq) (*moe.AdminBootstrapMenusResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).BootstrapMenus(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] bootstrap menus: %v", err)
		return nil, errorx.Internal("初始化菜单失败")
	}
	return resp, nil
}
