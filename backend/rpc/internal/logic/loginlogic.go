package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
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
		// 与客户端统一：忽略首尾空格；邮箱按小写匹配，避免大小写/输入法导致的「有时找不到账号」
		emailNorm := strings.ToLower(strings.TrimSpace(email))
		err = query.Where("LOWER(TRIM(email)) = ?", emailNorm).First(&user).Error
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
		l.Infof("[认证] 登录失败：未填写用户名或邮箱")
		return nil, errorx.New(400, "用户名或邮箱不能为空")
	}

	attempt := logutil.LoginAttemptTag(email, username)

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) || strings.Contains(err.Error(), "record not found") {
			l.Infof("[认证] 登录失败：账号不存在（未注册） %s", attempt)
			return nil, errorx.New(401, "账户未注册")
		}
		l.Errorf("[认证] 登录失败：查询用户时数据库异常 %s 错误=%v", attempt, err)
		return nil, errorx.New(401, "用户名或密码错误")
	}

	if !user.CheckPassword(in.Password) {
		l.Infof("[认证] 登录失败：密码不正确 用户ID=%d 用户名=%s Moe号=%s %s",
			user.ID, user.Username, user.MoeNo, attempt)
		return nil, errorx.New(401, "用户名或密码错误")
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("[认证] 登录过程异常：补全 Moe 号失败 用户ID=%d 错误=%v", user.ID, err)
	}

	// 3. 生成JWT令牌
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		l.Errorf("[认证] 登录失败：生成登录令牌失败 用户ID=%d 错误=%v", user.ID, err)
		return nil, errorx.New(500, "登录失败，请稍后重试")
	}

	_ = l.svcCtx.DB.First(&user, user.ID).Error

	l.Infof("[认证] 登录成功 用户ID=%d 用户名=%s Moe号=%s 邮箱=%s %s",
		user.ID, user.Username, user.MoeNo, logutil.MaskEmail(user.Email), attempt)

	return &super.LoginResp{
		User:  modelUserToProto(&user),
		Token: token,
	}, nil
}
