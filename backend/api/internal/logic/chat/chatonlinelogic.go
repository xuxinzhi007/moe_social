package chat

import (
	"context"

	"backend/api/internal/presence"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type ChatOnlineLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatOnlineLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatOnlineLogic {
	return &ChatOnlineLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatOnlineLogic) ChatOnline(req *types.ChatOnlineReq) (resp *types.ChatOnlineResp, err error) {
	online := presence.DefaultState.IsOnline(req.UserId)
	return &types.ChatOnlineResp{
		BaseResp: types.BaseResp{
			Code:    200,
			Message: "success",
			Success: true,
		},
		Online: online,
	}, nil
}
