package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
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
		l.Error("查找用户失败: ", result.Error)
		// 为了安全，通常不明确告知用户不存在，但RPC内部服务可以返回明确错误，由API层决定如何展示
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 更新密码
	// 直接赋值新密码，GORM的BeforeSave钩子会处理哈希
	// 注意：User模型中的BeforeSave只有在Password字段非空时才会哈希
	user.Password = in.NewPassword

	// 3. 保存更新
	err := l.svcCtx.DB.Save(&user).Error
	if err != nil {
		l.Error("更新密码失败: ", err)
		return nil, errorx.Internal("更新密码失败，请稍后重试")
	}

	return &super.ResetPasswordResp{}, nil
}
