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

type GetUserByEmailLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserByEmailLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserByEmailLogic {
	return &GetUserByEmailLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserByEmailLogic) GetUserByEmail(in *super.GetUserByEmailReq) (*super.GetUserByEmailResp, error) {
	var user model.User
	result := l.svcCtx.DB.Where("email = ?", in.Email).First(&user)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	_, _ = utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID)
	_ = l.svcCtx.DB.First(&user, user.ID).Error

	return &super.GetUserByEmailResp{
		User: modelUserToProto(&user),
	}, nil
}
