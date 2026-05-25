package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMenuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteMenuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMenuLogic {
	return &AdminDeleteMenuLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteMenuLogic) AdminDeleteMenu(in *super.AdminDeleteMenuReq) (*super.AdminDeleteMenuResp, error) {
	key := strings.TrimSpace(in.GetMenuKey())
	if key == "" {
		return nil, errorx.InvalidArgument("菜单 key 不能为空")
	}
	if err := l.svcCtx.DB.Where("`key` = ?", key).Delete(&model.AdminMenu{}).Error; err != nil {
		l.Errorf("[admin] delete menu: %v", err)
		return nil, errorx.Internal("删除菜单失败")
	}
	return &super.AdminDeleteMenuResp{}, nil
}
