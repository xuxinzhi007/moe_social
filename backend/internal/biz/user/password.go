package userbiz

import (
	"context"
	"errors"
	"strings"

	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

// UpdateUserPassword 校验旧密码后更新。
func UpdateUserPassword(ctx context.Context, store UserStore, in *moe.UpdateUserPasswordReq) (*moe.UpdateUserPasswordResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDString(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := store.GetUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if !user.CheckPassword(in.GetOldPassword()) {
		return nil, ErrWrongPassword
	}
	user.Password = in.GetNewPassword()
	if err := store.SaveUser(ctx, &user); err != nil {
		return nil, err
	}
	return &moe.UpdateUserPasswordResp{}, nil
}

// ResetPassword 按邮箱重置密码。
func ResetPassword(ctx context.Context, store UserStore, in *moe.ResetPasswordReq) (*moe.ResetPasswordResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	user, err := store.FindUserByEmail(ctx, in.GetEmail())
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	user.Password = in.GetNewPassword()
	if err := store.SaveUser(ctx, &user); err != nil {
		return nil, err
	}
	return &moe.ResetPasswordResp{}, nil
}

// GetUserByEmail 按邮箱查询用户。
func GetUserByEmail(ctx context.Context, store UserStore, in *moe.GetUserByEmailReq) (*moe.GetUserByEmailResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	email := strings.TrimSpace(in.GetEmail())
	user, err := store.FindUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if _, err := utils.EnsureUserMoeNo(store.Raw(), user.ID); err != nil {
		return nil, err
	}
	user, _ = store.ReloadUser(ctx, user.ID)
	return &moe.GetUserByEmailResp{User: ModelToProto(&user)}, nil
}
