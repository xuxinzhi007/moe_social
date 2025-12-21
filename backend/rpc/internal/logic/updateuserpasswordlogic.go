package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserPasswordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserPasswordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserPasswordLogic {
	return &UpdateUserPasswordLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateUserPasswordLogic) UpdateUserPassword(in *rpc.UpdateUserPasswordReq) (*rpc.UpdateUserPasswordResp, error) {
	// 1. 查找用户
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 验证旧密码
	if !user.CheckPassword(in.OldPassword) {
		return nil, errorx.InvalidArgument("旧密码不正确")
	}

	// 3. 更新密码
	user.Password = in.NewPassword
	err := l.svcCtx.DB.Save(&user).Error
	if err != nil {
		l.Error("更新密码失败: ", err)
		return nil, errorx.Internal("更新密码失败，请稍后重试")
	}

	// 4. 构建响应
	return &rpc.UpdateUserPasswordResp{}, nil
}
