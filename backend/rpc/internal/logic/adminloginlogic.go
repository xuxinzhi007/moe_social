package logic

import (
	"context"
	"errors"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminLoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminLoginLogic {
	return &AdminLoginLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminLoginLogic) AdminLogin(in *super.AdminLoginReq) (*super.AdminLoginResp, error) {
	username := strings.TrimSpace(in.GetUsername())
	password := in.GetPassword()
	if username == "" || password == "" {
		return nil, errorx.InvalidArgument("请输入用户名和密码")
	}

	var acc model.AdminAccount
	err := l.svcCtx.DB.Where("username = ?", username).First(&acc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, errorx.New(401, "用户名或密码错误")
	}
	if err != nil {
		l.Errorf("[admin] login query: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}
	if !acc.CheckPassword(password) {
		return nil, errorx.New(401, "用户名或密码错误")
	}

	token, exp, err := utils.GenerateAdminToken(acc.ID, acc.Username, acc.Role)
	if err != nil {
		l.Errorf("[admin] token: %v", err)
		return nil, errorx.Internal("登录失败")
	}

	now := time.Now()
	_ = l.svcCtx.DB.Model(&acc).Update("last_login_at", now).Error

	return &super.AdminLoginResp{
		Token:     token,
		AdminId:   uint64(acc.ID),
		Username:  acc.Username,
		Role:      acc.Role,
		ExpireAt:  exp.Unix(),
	}, nil
}
