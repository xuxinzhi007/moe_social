package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendFeishuTestCardLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSendFeishuTestCardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendFeishuTestCardLogic {
	return &SendFeishuTestCardLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SendFeishuTestCardLogic) SendFeishuTestCard(in *super.SendFeishuTestCardReq) (*super.SendFeishuTestCardResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的 user_id")
	}

	var user model.User
	if err := l.svcCtx.DB.Select("id", "feishu_email").First(&user, uint(userID)).Error; err != nil {
		return nil, errorx.NotFound("用户不存在")
	}
	target := strings.TrimSpace(user.FeishuEmail)
	if target == "" {
		return nil, errorx.InvalidArgument("请先绑定企业飞书邮箱")
	}

	if err := utils.SendFeishuTestCard(l.ctx, target); err != nil {
		return nil, err
	}
	return &super.SendFeishuTestCardResp{}, nil
}
