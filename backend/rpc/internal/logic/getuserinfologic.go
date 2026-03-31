package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserInfoLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserInfoLogic {
	return &GetUserInfoLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *GetUserInfoLogic) GetUserInfo(in *super.GetUserInfoReq) (*super.GetUserInfoResp, error) {
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("ensure moe_no: %v", err)
	}
	_ = l.svcCtx.DB.First(&user, user.ID).Error

	return &super.GetUserInfoResp{
		User: modelUserToProto(&user),
	}, nil
}
