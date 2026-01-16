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

type DeleteUserMemoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteUserMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteUserMemoryLogic {
	return &DeleteUserMemoryLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteUserMemoryLogic) DeleteUserMemory(in *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error) {
	if in.UserId == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}
	if in.Key == "" {
		return nil, errorx.InvalidArgument("key不能为空")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	result := l.svcCtx.DB.Where("user_id = ? AND `key` = ?", uint(userID), in.Key).
		Delete(&model.UserMemory{})
	if result.Error != nil {
		l.Error("删除用户记忆失败: ", result.Error)
		return nil, errorx.Internal("删除用户记忆失败")
	}
	if result.RowsAffected == 0 {
		return nil, errorx.NotFound("用户记忆不存在")
	}

	return &super.DeleteUserMemoryResp{}, nil
}

