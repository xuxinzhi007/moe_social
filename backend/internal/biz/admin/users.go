package adminbiz

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// UserPage Admin 用户列表筛选。
type UserPage struct {
	Page     int32
	PageSize int32
	Keyword  string
}

// ListUsers Admin 用户列表。
func ListUsers(ctx context.Context, store AdminStore, in UserPage) ([]*moe.User, int32, error) {
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

	out := make([]*moe.User, 0, len(users))
	for i := range users {
		out = append(out, userbiz.ModelToProto(&users[i]))
	}
	return out, int32(total), nil
}
