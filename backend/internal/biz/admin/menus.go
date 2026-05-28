package adminbiz

import (
	"context"

	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// ListMenus Admin 菜单树列表。
func ListMenus(ctx context.Context, store AdminStore) ([]*moe.AdminMenuItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	rows, err := store.ListMenus(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]*moe.AdminMenuItem, len(rows))
	for i, row := range rows {
		items[i] = menuItemToProto(row)
	}
	return items, nil
}
