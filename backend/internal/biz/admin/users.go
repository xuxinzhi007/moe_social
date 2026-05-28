package adminbiz

import (
	"context"
	"strings"

	userbiz "backend/internal/biz/user"
	"backend/model"
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
func ListUsers(ctx context.Context, db *gorm.DB, in UserPage) ([]*moe.User, int32, error) {
	if db == nil {
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

	q := db.WithContext(ctx).Model(&model.User{})
	if kw := strings.TrimSpace(in.Keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("username LIKE ? OR email LIKE ? OR moe_no LIKE ?", like, like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var users []model.User
	offset := int((page - 1) * pageSize)
	if err := q.Order("id ASC").Offset(offset).Limit(int(pageSize)).Find(&users).Error; err != nil {
		return nil, 0, err
	}

	out := make([]*moe.User, 0, len(users))
	for i := range users {
		out = append(out, userbiz.ModelToProto(&users[i]))
	}
	return out, int32(total), nil
}
