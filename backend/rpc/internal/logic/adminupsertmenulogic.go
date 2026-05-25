package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminUpsertMenuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpsertMenuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpsertMenuLogic {
	return &AdminUpsertMenuLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpsertMenuLogic) AdminUpsertMenu(in *super.AdminUpsertMenuReq) (*super.AdminUpsertMenuResp, error) {
	key := strings.TrimSpace(in.GetKey())
	if key == "" {
		return nil, errorx.InvalidArgument("菜单 key 不能为空")
	}
	kind := strings.TrimSpace(in.GetKind())
	if kind == "" {
		return nil, errorx.InvalidArgument("菜单 kind 不能为空")
	}
	label := strings.TrimSpace(in.GetLabel())
	if label == "" {
		return nil, errorx.InvalidArgument("菜单 label 不能为空")
	}

	var row model.AdminMenu
	err := l.svcCtx.DB.Where("`key` = ?", key).First(&row).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		l.Errorf("[admin] upsert menu lookup: %v", err)
		return nil, errorx.Internal("保存菜单失败")
	}

	row.Key = key
	row.Kind = kind
	row.ParentKey = strings.TrimSpace(in.GetParentKey())
	row.Path = strings.TrimSpace(in.GetPath())
	row.Label = label
	row.Icon = strings.TrimSpace(in.GetIcon())
	row.Caption = strings.TrimSpace(in.GetCaption())
	row.Status = strings.TrimSpace(in.GetStatus())
	if row.Status == "" {
		row.Status = "planned"
	}
	row.AppDomain = strings.TrimSpace(in.GetAppDomain())
	row.SortOrder = int(in.GetSortOrder())
	row.DefaultOpen = in.GetDefaultOpen()
	row.End = in.GetEnd()
	row.ExternalHref = strings.TrimSpace(in.GetExternalHref())
	row.Enabled = true
	if err != gorm.ErrRecordNotFound {
		row.Enabled = in.GetEnabled()
	}

	if err == gorm.ErrRecordNotFound {
		if err := l.svcCtx.DB.Create(&row).Error; err != nil {
			l.Errorf("[admin] create menu: %v", err)
			return nil, errorx.Internal("保存菜单失败")
		}
	} else {
		if err := l.svcCtx.DB.Save(&row).Error; err != nil {
			l.Errorf("[admin] update menu: %v", err)
			return nil, errorx.Internal("保存菜单失败")
		}
	}
	return &super.AdminUpsertMenuResp{Menu: adminMenuToProto(row)}, nil
}
