package adminbiz

import (
	"context"

	adminv1 "backend/api/admin/v1"

	"gorm.io/gorm"
)

// UserPage Admin 用户列表筛选。
type UserPage struct {
	Page     int32
	PageSize int32
	Keyword  string
}

// ListUsers Admin 用户列表。
func ListUsers(ctx context.Context, store AdminStore, in UserPage) ([]*adminv1.User, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	offset := int((page - 1) * pageSize)
	users, total, err := store.ListUsers(ctx, in.Keyword, offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}

	out := make([]*adminv1.User, 0, len(users))
	for i := range users {
		out = append(out, userModelToAdminV1(&users[i]))
	}
	return out, int32(total), nil
}
