package logic

import (
	"context"
	"errors"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type ResetPasswordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewResetPasswordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ResetPasswordLogic {
	return &ResetPasswordLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ResetPasswordLogic) ResetPassword(in *super.ResetPasswordReq) (*super.ResetPasswordResp, error) {
	// 1. 查找用户
	var user model.User
	result := l.svcCtx.DB.Where("email = ?", in.Email).First(&user)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			l.Infof("[认证] 重置密码失败：未找到该邮箱对应用户 邮箱=%s", logutil.MaskEmail(in.Email))
		} else {
			l.Errorf("[认证] 重置密码失败：查询用户时数据库异常 邮箱=%s 错误=%v",
				logutil.MaskEmail(in.Email), result.Error)
		}
		// 对外仍统一返回「用户不存在」，避免枚举邮箱
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 更新密码
	// 直接赋值新密码，GORM的BeforeSave钩子会处理哈希
	// 注意：User模型中的BeforeSave只有在Password字段非空时才会哈希
	user.Password = in.NewPassword

	// 3. 保存更新
	err := l.svcCtx.DB.Save(&user).Error
	if err != nil {
		l.Errorf("[认证] 重置密码失败：保存新密码时数据库异常 用户ID=%d 邮箱=%s 错误=%v",
			user.ID, logutil.MaskEmail(in.Email), err)
		return nil, errorx.Internal("更新密码失败，请稍后重试")
	}

	l.Infof("[认证] 重置密码成功 用户ID=%d 用户名=%s 邮箱=%s",
		user.ID, user.Username, logutil.MaskEmail(user.Email))

	return &super.ResetPasswordResp{}, nil
}
