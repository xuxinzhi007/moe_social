package adminbiz

import (
	"context"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// ListMenus Admin 菜单树列表。
func ListMenus(ctx context.Context, db *gorm.DB) ([]*moe.AdminMenuItem, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	var rows []model.AdminMenu
	if err := db.WithContext(ctx).Order("sort_order ASC, id ASC").Find(&rows).Error; err != nil {
		return nil, err
	}
	items := make([]*moe.AdminMenuItem, len(rows))
	for i, row := range rows {
		items[i] = menuItemToProto(row)
	}
	return items, nil
}
