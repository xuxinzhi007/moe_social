package adminbiz

import (
	"context"
	"errors"
	"strings"

	"backend/rpc/pb/moe"
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
func UpsertMenu(ctx context.Context, store AdminStore, in UpsertMenuInput) (*moe.AdminMenuItem, error) {
	if store == nil {
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

	row, err := store.FindMenuByKey(ctx, key)
	isNew := errors.Is(err, gorm.ErrRecordNotFound)
	if err != nil && !isNew {
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
	if !isNew {
		row.Enabled = in.Enabled
	}

	if isNew {
		if err := store.CreateMenu(ctx, &row); err != nil {
			return nil, err
		}
	} else {
		if err := store.SaveMenu(ctx, &row); err != nil {
			return nil, err
		}
	}
	return menuItemToProto(row), nil
}

// DeleteMenu 按 key 删除菜单。
func DeleteMenu(ctx context.Context, store AdminStore, menuKey string) error {
	if store == nil {
		return gorm.ErrInvalidDB
	}
	key := strings.TrimSpace(menuKey)
	if key == "" {
		return ErrEmptyMenuKey
	}
	return store.DeleteMenuByKey(ctx, key)
}

// BootstrapMenus 空表时导入默认管理台菜单。
func BootstrapMenus(ctx context.Context, store AdminStore) (int32, error) {
	if store == nil {
		return 0, gorm.ErrInvalidDB
	}
	_ = ctx
	created, err := utils.BootstrapAdminMenus(store.Raw())
	if err != nil {
		return 0, err
	}
	return created, nil
}
