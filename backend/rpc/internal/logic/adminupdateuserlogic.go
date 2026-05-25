package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminUpdateUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateUserLogic {
	return &AdminUpdateUserLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateUserLogic) AdminUpdateUser(in *super.AdminUpdateUserReq) (*super.AdminUpdateUserResp, error) {
	if in.GetUserId() == 0 {
		return nil, errorx.InvalidArgument("无效的用户 ID")
	}

	var user model.User
	if err := l.svcCtx.DB.First(&user, in.GetUserId()).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("用户不存在")
		}
		return nil, errorx.Internal("服务器内部错误")
	}

	updates := map[string]interface{}{}
	if role := strings.TrimSpace(in.GetRole()); role != "" {
		switch role {
		case "user", "admin", "super_admin":
			updates["role"] = role
		default:
			return nil, errorx.InvalidArgument("无效的角色")
		}
	}
	if in.GetUpdateIsVip() {
		updates["is_vip"] = in.GetIsVip()
	}
	if in.GetUpdateSignature() {
		updates["signature"] = strings.TrimSpace(in.GetSignature())
	}
	if in.GetUpdateAvatar() {
		updates["avatar"] = strings.TrimSpace(in.GetAvatar())
	}
	if len(updates) == 0 {
		return &super.AdminUpdateUserResp{User: modelUserToProto(&user)}, nil
	}

	if err := l.svcCtx.DB.Model(&user).Updates(updates).Error; err != nil {
		l.Errorf("[admin] update user: %v", err)
		return nil, errorx.Internal("更新失败")
	}
	if err := l.svcCtx.DB.First(&user, user.ID).Error; err != nil {
		return nil, errorx.Internal("服务器内部错误")
	}
	return &super.AdminUpdateUserResp{User: modelUserToProto(&user)}, nil
}
