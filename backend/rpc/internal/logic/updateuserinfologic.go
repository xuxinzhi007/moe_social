package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserInfoLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserInfoLogic {
	return &UpdateUserInfoLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateUserInfoLogic) UpdateUserInfo(in *super.UpdateUserInfoReq) (*super.UpdateUserInfoResp, error) {
	// 1. 查找用户
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 更新用户信息
	if in.Username != "" {
		user.Username = in.Username
	}
	if in.Email != "" {
		user.Email = in.Email
	}
	// 更新头像（即使为空字符串也要更新，允许清空头像）
	user.Avatar = in.Avatar

	// 3. 保存更新
	err := l.svcCtx.DB.Save(&user).Error
	if err != nil {
		l.Error("更新用户信息失败: ", err)
		return nil, errorx.Internal("更新用户信息失败，请稍后重试")
	}

	// 4. 构建响应
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}

	return &super.UpdateUserInfoResp{
		User: &super.User{
			Id:           strconv.Itoa(int(user.ID)),
			Username:     user.Username,
			Email:        user.Email,
			Avatar:       user.Avatar,
			CreatedAt:    user.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:    user.UpdatedAt.Format("2006-01-02 15:04:05"),
			IsVip:        user.IsVip,
			VipExpiresAt: vipEndAt,
			AutoRenew:    user.AutoRenew,
		},
	}, nil
}
