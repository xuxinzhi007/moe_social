package adminbiz

import (
	"context"

	adminv1 "backend/api/admin/v1"

	"gorm.io/gorm"
)

// ListMenus Admin 菜单树列表。
func ListMenus(ctx context.Context, store AdminStore) ([]*adminv1.AdminMenuItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	rows, err := store.ListMenus(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]*adminv1.AdminMenuItem, len(rows))
	for i, row := range rows {
		items[i] = menuItemToProto(row)
	}
	return items, nil
}
