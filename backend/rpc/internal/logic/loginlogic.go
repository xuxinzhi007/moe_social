package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type LoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LoginLogic {
	return &LoginLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func isTenDigitMoe(s string) bool {
	if len(s) != 10 {
		return false
	}
	for i := 0; i < 10; i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

func (l *LoginLogic) Login(in *super.LoginReq) (*super.LoginResp, error) {
	// 1. 查找用户：邮箱优先；否则 10 位数字按 Moe 号再按用户名；否则按用户名
	var user model.User
	var err error

	query := l.svcCtx.DB
	email := strings.TrimSpace(in.Email)
	username := strings.TrimSpace(in.Username)

	if email != "" {
		err = query.Where("email = ?", email).First(&user).Error
	} else if username != "" {
		if isTenDigitMoe(username) {
			err = query.Where("moe_no = ?", username).First(&user).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				err = query.Where("username = ?", username).First(&user).Error
			}
		} else {
			err = query.Where("username = ?", username).First(&user).Error
		}
	} else {
		return nil, errorx.New(400, "用户名或邮箱不能为空")
	}

	if err != nil {
		l.Error("查找用户失败: ", err)
		if errors.Is(err, gorm.ErrRecordNotFound) || strings.Contains(err.Error(), "record not found") {
			return nil, errorx.New(401, "账户未注册")
		}
		return nil, errorx.New(401, "用户名或密码错误")
	}

	// 2. 验证密码
	if !user.CheckPassword(in.Password) {
		return nil, errorx.New(401, "用户名或密码错误")
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("ensure moe_no: %v", err)
	}

	// 3. 生成JWT令牌
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		l.Error("生成令牌失败: ", err)
		return nil, errorx.New(500, "登录失败，请稍后重试")
	}

	_ = l.svcCtx.DB.First(&user, user.ID).Error

	return &super.LoginResp{
		User:  modelUserToProto(&user),
		Token: token,
	}, nil
}
