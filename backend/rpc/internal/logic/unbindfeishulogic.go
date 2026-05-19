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

type UnbindFeishuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUnbindFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UnbindFeishuLogic {
	return &UnbindFeishuLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UnbindFeishuLogic) UnbindFeishu(in *super.UnbindFeishuReq) (*super.UnbindFeishuResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的 user_id")
	}

	var user model.User
	if err := l.svcCtx.DB.First(&user, uint(userID)).Error; err != nil {
		return nil, errorx.NotFound("用户不存在")
	}
	user.FeishuEmail = ""
	if err := l.svcCtx.DB.Save(&user).Error; err != nil {
		return nil, err
	}
	return &super.UnbindFeishuResp{User: modelUserToProto(&user)}, nil
}
