package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteUserLogic {
	return &DeleteUserLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteUserLogic) DeleteUser(in *rpc.DeleteUserReq) (*rpc.DeleteUserResp, error) {
	// 1. 查找用户，确认用户存在
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 删除用户
	err := l.svcCtx.DB.Delete(&user).Error
	if err != nil {
		l.Error("删除用户失败: ", err)
		return nil, errorx.Internal("删除用户失败，请稍后重试")
	}

	// 3. 构建响应
	return &rpc.DeleteUserResp{}, nil
}
