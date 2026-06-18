// Package userapp 用户信息查询与更新。
package userapp

import (
	"context"
	"strconv"
	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
)

// Package userapp 用户信息查询与更新。

func parseUserID(raw string) (uint, error) {
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, userbiz.ErrInvalidArgument
	}
	return uint(n), nil
}

// GetUserInfo 按 ID 查询。
func (s *AppService) GetUserInfo(ctx context.Context, in *userv1.GetUserInfoReq) (*userv1.GetUserInfoResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := userbiz.GetByID(ctx, s.store, uid)
	if err != nil {
		return nil, err
	}
	return userbiz.UserInfoRespV1(user), nil
}

// GetUser 同 GetUserInfo（super 契约）。
func (s *AppService) GetUser(ctx context.Context, in *userv1.GetUserReq) (*userv1.GetUserResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := userbiz.GetByID(ctx, s.store, uid)
	if err != nil {
		return nil, err
	}
	return userbiz.GetUserRespV1(user), nil
}

// GetUsers 用户列表。
func (s *AppService) GetUsers(ctx context.Context, in *userv1.GetUsersReq) (*userv1.GetUsersResp, error) {
	return userbiz.GetUsers(ctx, s.store, in)
}

// GetUserCount 用户总数。
func (s *AppService) GetUserCount(ctx context.Context, in *userv1.GetUserCountReq) (*userv1.GetUserCountResp, error) {
	return userbiz.GetUserCount(ctx, s.store, in)
}

// GetUserByEmail 按邮箱查询。
func (s *AppService) GetUserByEmail(ctx context.Context, in *userv1.GetUserByEmailReq) (*userv1.GetUserByEmailResp, error) {
	return userbiz.GetUserByEmail(ctx, s.store, in)
}

// UpdateUserInfo 更新用户信息。
func (s *AppService) UpdateUserInfo(ctx context.Context, in *userv1.UpdateUserInfoReq) (*userv1.UpdateUserInfoResp, error) {
	return userbiz.UpdateUserInfo(ctx, s.store, in)
}

// UpdateUserPassword 更新密码。
func (s *AppService) UpdateUserPassword(ctx context.Context, in *userv1.UpdateUserPasswordReq) (*userv1.UpdateUserPasswordResp, error) {
	return userbiz.UpdateUserPassword(ctx, s.store, in)
}

// ResetPassword 重置密码。
func (s *AppService) ResetPassword(ctx context.Context, in *userv1.ResetPasswordReq) (*userv1.ResetPasswordResp, error) {
	return userbiz.ResetPassword(ctx, s.store, in)
}

// DeleteUser 删除用户。
func (s *AppService) DeleteUser(ctx context.Context, in *userv1.DeleteUserReq) (*userv1.DeleteUserResp, error) {
	return userbiz.DeleteUser(ctx, s.store, in)
}

// GetUserAvatar 获取用户虚拟形象。
func (s *AppService) GetUserAvatar(ctx context.Context, in *userv1.GetUserAvatarReq) (*userv1.GetUserAvatarResp, error) {
	return userbiz.GetUserAvatar(ctx, s.store, in)
}

// UpdateUserAvatar 更新用户虚拟形象。
func (s *AppService) UpdateUserAvatar(ctx context.Context, in *userv1.UpdateUserAvatarReq) (*userv1.UpdateUserAvatarResp, error) {
	return userbiz.UpdateUserAvatar(ctx, s.store, in)
}