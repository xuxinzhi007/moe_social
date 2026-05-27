package userbiz

import (
	"context"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// GetUsers 分页列出用户。
func GetUsers(ctx context.Context, db *gorm.DB, in *super.GetUsersReq) (*super.GetUsersResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (page - 1) * pageSize

	var users []model.User
	var total int64
	if err := db.WithContext(ctx).Model(&model.User{}).Count(&total).Error; err != nil {
		return nil, err
	}
	if err := db.WithContext(ctx).Offset(int(offset)).Limit(int(pageSize)).Find(&users).Error; err != nil {
		return nil, err
	}

	respUsers := make([]*super.User, len(users))
	for i := range users {
		u := users[i]
		respUsers[i] = ModelToProto(&u)
	}
	return &super.GetUsersResp{Users: respUsers, Total: int32(total)}, nil
}

// GetUserCount 返回用户总数。
func GetUserCount(ctx context.Context, db *gorm.DB, _ *super.GetUserCountReq) (*super.GetUserCountResp, error) {
	var total int64
	if err := db.WithContext(ctx).Model(&model.User{}).Count(&total).Error; err != nil {
		return nil, err
	}
	return &super.GetUserCountResp{Count: int32(total)}, nil
}
