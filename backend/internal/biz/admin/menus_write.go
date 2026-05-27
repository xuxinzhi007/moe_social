package adminbiz

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

var (
	ErrEmptyMenuKey   = errors.New("empty menu key")
	ErrEmptyMenuKind  = errors.New("empty menu kind")
	ErrEmptyMenuLabel = errors.New("empty menu label")
)

// UpsertMenuInput Admin 菜单 upsert。
type UpsertMenuInput struct {
	Key          string
	Kind         string
	ParentKey    string
	Path         string
	Label        string
	Icon         string
	Caption      string
	Status       string
	AppDomain    string
	SortOrder    int32
	DefaultOpen  bool
	End          bool
	ExternalHref string
	Enabled      bool
}

// UpsertMenu 创建或更新菜单项。
func UpsertMenu(ctx context.Context, db *gorm.DB, in UpsertMenuInput) (*super.AdminMenuItem, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	key := strings.TrimSpace(in.Key)
	if key == "" {
		return nil, ErrEmptyMenuKey
	}
	kind := strings.TrimSpace(in.Kind)
	if kind == "" {
		return nil, ErrEmptyMenuKind
	}
	label := strings.TrimSpace(in.Label)
	if label == "" {
		return nil, ErrEmptyMenuLabel
	}

	var row model.AdminMenu
	err := db.WithContext(ctx).Where("`key` = ?", key).First(&row).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	row.Key = key
	row.Kind = kind
	row.ParentKey = strings.TrimSpace(in.ParentKey)
	row.Path = strings.TrimSpace(in.Path)
	row.Label = label
	row.Icon = strings.TrimSpace(in.Icon)
	row.Caption = strings.TrimSpace(in.Caption)
	row.Status = strings.TrimSpace(in.Status)
	if row.Status == "" {
		row.Status = "planned"
	}
	row.AppDomain = strings.TrimSpace(in.AppDomain)
	row.SortOrder = int(in.SortOrder)
	row.DefaultOpen = in.DefaultOpen
	row.End = in.End
	row.ExternalHref = strings.TrimSpace(in.ExternalHref)
	row.Enabled = true
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		row.Enabled = in.Enabled
	}

	if errors.Is(err, gorm.ErrRecordNotFound) {
		if err := db.WithContext(ctx).Create(&row).Error; err != nil {
			return nil, err
		}
	} else {
		if err := db.WithContext(ctx).Save(&row).Error; err != nil {
			return nil, err
		}
	}
	return menuItemToProto(row), nil
}

// DeleteMenu 按 key 删除菜单。
func DeleteMenu(ctx context.Context, db *gorm.DB, menuKey string) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	key := strings.TrimSpace(menuKey)
	if key == "" {
		return ErrEmptyMenuKey
	}
	return db.WithContext(ctx).Where("`key` = ?", key).Delete(&model.AdminMenu{}).Error
}

// BootstrapMenus 空表时导入默认管理台菜单。
func BootstrapMenus(ctx context.Context, db *gorm.DB) (int32, error) {
	if db == nil {
		return 0, gorm.ErrInvalidDB
	}
	_ = ctx
	created, err := utils.BootstrapAdminMenus(db)
	if err != nil {
		return 0, err
	}
	return created, nil
}
