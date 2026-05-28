package adminbiz

import (
	"context"
	"errors"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

var (
	// ErrAdminLoginEmpty 用户名或密码为空。
	ErrAdminLoginEmpty = errors.New("admin login empty credentials")
	// ErrAdminAuthFailed 用户名或密码错误。
	ErrAdminAuthFailed = errors.New("admin auth failed")
)

// AdminLogin 管理端账号登录。
func AdminLogin(ctx context.Context, db *gorm.DB, in *super.AdminLoginReq) (*super.AdminLoginResp, error) {
	if db == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	username := strings.TrimSpace(in.GetUsername())
	password := in.GetPassword()
	if username == "" || password == "" {
		return nil, ErrAdminLoginEmpty
	}
	var acc model.AdminAccount
	err := db.WithContext(ctx).Where("username = ?", username).First(&acc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAdminAuthFailed
	}
	if err != nil {
		return nil, err
	}
	if !acc.CheckPassword(password) {
		return nil, ErrAdminAuthFailed
	}
	token, exp, err := utils.GenerateAdminToken(acc.ID, acc.Username, acc.Role)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	_ = db.WithContext(ctx).Model(&acc).Update("last_login_at", now).Error
	return &super.AdminLoginResp{
		Token:    token,
		AdminId:  uint64(acc.ID),
		Username: acc.Username,
		Role:     acc.Role,
		ExpireAt: exp.Unix(),
	}, nil
}

// BootstrapAdminAccount 无管理员时创建默认超管。
func BootstrapAdminAccount(ctx context.Context, db *gorm.DB, in *super.AdminBootstrapAccountReq) (*super.AdminBootstrapAccountResp, error) {
	_ = ctx
	_ = in
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	created := utils.BootstrapAdminAccount(db)
	return &super.AdminBootstrapAccountResp{Created: created}, nil
}
