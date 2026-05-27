// Package userapp User 域应用服务（FS-3 Hybrid）。
package userapp

import (
	"context"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService User 应用服务。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

// Login 登录。
func (s *AppService) Login(ctx context.Context, in *super.LoginReq) (*super.LoginResp, error) {
	user, token, err := userbiz.Login(ctx, s.db, in.GetEmail(), in.GetUsername(), in.GetPassword())
	if err != nil {
		return nil, err
	}
	return &super.LoginResp{
		User:  userbiz.ModelToProto(&user),
		Token: token,
	}, nil
}

// Register 注册。
func (s *AppService) Register(ctx context.Context, in *super.RegisterReq) (*super.RegisterResp, error) {
	user, token, err := userbiz.Register(ctx, s.db, in.GetUsername(), in.GetEmail(), in.GetPassword())
	if err != nil {
		return nil, err
	}
	return &super.RegisterResp{
		User:  userbiz.ModelToProto(&user),
		Token: token,
	}, nil
}

func parseUserID(raw string) (uint, error) {
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, userbiz.ErrInvalidArgument
	}
	return uint(n), nil
}

// GetUserInfo 按 ID 查询。
func (s *AppService) GetUserInfo(ctx context.Context, in *super.GetUserInfoReq) (*super.GetUserInfoResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := userbiz.GetByID(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.GetUserInfoResp{User: userbiz.ModelToProto(&user)}, nil
}

// GetUser 同 GetUserInfo（super 契约）。
func (s *AppService) GetUser(ctx context.Context, in *super.GetUserReq) (*super.GetUserResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := userbiz.GetByID(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.GetUserResp{User: userbiz.ModelToProto(&user)}, nil
}

// GetUserVipStatus VIP 状态。
func (s *AppService) GetUserVipStatus(ctx context.Context, in *super.GetUserVipStatusReq) (*super.GetUserVipStatusResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	st, err := userbiz.GetVipStatus(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.GetUserVipStatusResp{
		IsVip:     st.IsVip,
		ExpiresAt: st.ExpiresAt,
		AutoRenew: st.AutoRenew,
	}, nil
}

// CheckUserVip 是否有效 VIP。
func (s *AppService) CheckUserVip(ctx context.Context, in *super.CheckUserVipReq) (*super.CheckUserVipResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	active, err := userbiz.CheckVipActive(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.CheckUserVipResp{IsVip: active}, nil
}

// DB 暴露给渐进迁移（仅 Hybrid 内部）。
func (s *AppService) DB() *gorm.DB {
	return s.db
}

// EnsureUser 加载用户（供扩展）。
func (s *AppService) EnsureUser(ctx context.Context, userID uint) (model.User, error) {
	return userbiz.GetByID(ctx, s.db, userID)
}
