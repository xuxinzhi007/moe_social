package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type BindFeishuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewBindFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *BindFeishuLogic {
	return &BindFeishuLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *BindFeishuLogic) BindFeishu(in *super.BindFeishuReq) (*super.BindFeishuResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的 user_id")
	}
	email, err := utils.NormalizeFeishuEmail(in.GetFeishuEmail())
	if err != nil {
		return nil, errorx.InvalidArgument(err.Error())
	}

	var user model.User
	if err := l.svcCtx.DB.First(&user, uint(userID)).Error; err != nil {
		return nil, errorx.NotFound("用户不存在")
	}
	user.FeishuEmail = email
	if err := l.svcCtx.DB.Save(&user).Error; err != nil {
		return nil, err
	}
	return &super.BindFeishuResp{User: modelUserToProto(&user)}, nil
}
