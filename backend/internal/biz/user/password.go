package userbiz

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

// UpdateUserPassword 校验旧密码后更新。
func UpdateUserPassword(ctx context.Context, db *gorm.DB, in *moe.UpdateUserPasswordReq) (*moe.UpdateUserPasswordResp, error) {
	var user model.User
	if err := db.WithContext(ctx).First(&user, in.GetUserId()).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if !user.CheckPassword(in.GetOldPassword()) {
		return nil, ErrWrongPassword
	}
	user.Password = in.GetNewPassword()
	if err := db.WithContext(ctx).Save(&user).Error; err != nil {
		return nil, err
	}
	return &moe.UpdateUserPasswordResp{}, nil
}

// ResetPassword 按邮箱重置密码。
func ResetPassword(ctx context.Context, db *gorm.DB, in *moe.ResetPasswordReq) (*moe.ResetPasswordResp, error) {
	var user model.User
	err := db.WithContext(ctx).Where("email = ?", in.GetEmail()).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	user.Password = in.GetNewPassword()
	if err := db.WithContext(ctx).Save(&user).Error; err != nil {
		return nil, err
	}
	return &moe.ResetPasswordResp{}, nil
}

// GetUserByEmail 按邮箱查询用户。
func GetUserByEmail(ctx context.Context, db *gorm.DB, in *moe.GetUserByEmailReq) (*moe.GetUserByEmailResp, error) {
	email := strings.TrimSpace(in.GetEmail())
	var user model.User
	if err := db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if _, err := utils.EnsureUserMoeNo(db, user.ID); err != nil {
		return nil, err
	}
	_ = db.WithContext(ctx).First(&user, user.ID).Error
	return &moe.GetUserByEmailResp{User: ModelToProto(&user)}, nil
}
