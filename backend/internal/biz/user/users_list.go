package userbiz

import (
	"context"

	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// GetUsers 分页列出用户。
func GetUsers(ctx context.Context, store UserStore, in *moe.GetUsersReq) (*moe.GetUsersResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := int((page - 1) * pageSize)

	total, err := store.CountUsers(ctx)
	if err != nil {
		return nil, err
	}
	users, err := store.ListUsers(ctx, offset, int(pageSize))
	if err != nil {
		return nil, err
	}

	respUsers := make([]*moe.User, len(users))
	for i := range users {
		u := users[i]
		respUsers[i] = ModelToProto(&u)
	}
	return &moe.GetUsersResp{Users: respUsers, Total: int32(total)}, nil
}

// GetUserCount 返回用户总数。
func GetUserCount(ctx context.Context, store UserStore, _ *moe.GetUserCountReq) (*moe.GetUserCountResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	total, err := store.CountUsers(ctx)
	if err != nil {
		return nil, err
	}
	return &moe.GetUserCountResp{Count: int32(total)}, nil
}
