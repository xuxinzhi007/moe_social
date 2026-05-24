package logic

import (
	"context"
	"errors"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminGetUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetUserLogic {
	return &AdminGetUserLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetUserLogic) AdminGetUser(in *super.AdminGetUserReq) (*super.AdminGetUserResp, error) {
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
	return &super.AdminGetUserResp{User: modelUserToProto(&user)}, nil
}
