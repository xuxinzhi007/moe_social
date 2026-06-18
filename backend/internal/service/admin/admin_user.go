package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListUsers(ctx context.Context, in *adminv1.AdminListUsersReq) (*adminv1.AdminListUsersResp, error) {
	users, total, err := adminbiz.ListUsers(ctx, s.store, adminbiz.UserPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListUsersV1(users, total), nil
}

func (s *AppService) UpdateUser(ctx context.Context, in *adminv1.AdminUpdateUserReq) (*adminv1.AdminUpdateUserResp, error) {
	user, err := adminbiz.UpdateUser(ctx, s.store, adminbiz.UpdateUserInput{
		UserID:          uint(in.GetUserId()),
		Role:            in.GetRole(),
		IsVip:           in.GetIsVip(),
		UpdateIsVip:     in.GetUpdateIsVip(),
		Signature:       in.GetSignature(),
		UpdateSignature: in.GetUpdateSignature(),
		Avatar:          in.GetAvatar(),
		UpdateAvatar:    in.GetUpdateAvatar(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.UpdateUserV1(user), nil
}

func (s *AppService) GetUser(ctx context.Context, in *adminv1.AdminGetUserReq) (*adminv1.AdminGetUserResp, error) {
	out, err := adminbiz.GetUser(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) GetUserProfile(ctx context.Context, in *adminv1.AdminGetUserProfileReq) (*adminv1.AdminGetUserProfileResp, error) {
	out, err := adminbiz.GetUserProfile(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
