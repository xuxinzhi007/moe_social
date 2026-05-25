package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
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

func (l *AdminListMenusLogic) AdminListMenus(_ *super.AdminListMenusReq) (*super.AdminListMenusResp, error) {
	var rows []model.AdminMenu
	if err := l.svcCtx.DB.Order("sort_order ASC, id ASC").Find(&rows).Error; err != nil {
		l.Errorf("[admin] list menus: %v", err)
		return nil, errorx.Internal("查询菜单失败")
	}
	items := make([]*super.AdminMenuItem, len(rows))
	for i, row := range rows {
		items[i] = adminMenuToProto(row)
	}
	return &super.AdminListMenusResp{Items: items}, nil
}
