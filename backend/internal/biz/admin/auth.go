package adminbiz

import (
	"context"
	"errors"
	"strings"
	"time"

	"backend/rpc/pb/moe"
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
func AdminLogin(ctx context.Context, store AdminStore, in *moe.AdminLoginReq) (*moe.AdminLoginResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	username := strings.TrimSpace(in.GetUsername())
	password := in.GetPassword()
	if username == "" || password == "" {
		return nil, ErrAdminLoginEmpty
	}
	acc, err := store.FindAdminAccountByUsername(ctx, username)
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
	_ = store.UpdateAdminLastLoginAt(ctx, acc.ID, now)
	return &moe.AdminLoginResp{
		Token:    token,
		AdminId:  uint64(acc.ID),
		Username: acc.Username,
		Role:     acc.Role,
		ExpireAt: exp.Unix(),
	}, nil
}

// BootstrapAdminAccount 无管理员时创建默认超管。
func BootstrapAdminAccount(ctx context.Context, store AdminStore, in *moe.AdminBootstrapAccountReq) (*moe.AdminBootstrapAccountResp, error) {
	_ = ctx
	_ = in
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	created := utils.BootstrapAdminAccount(store.Raw())
	return &moe.AdminBootstrapAccountResp{Created: created}, nil
}
