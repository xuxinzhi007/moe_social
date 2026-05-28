package logic

import (
	"context"

	chatbiz "backend/internal/biz/chat"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendPrivateMessageLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSendPrivateMessageLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendPrivateMessageLogic {
	return &SendPrivateMessageLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SendPrivateMessageLogic) SendPrivateMessage(in *moe.SendPrivateMessageReq) (*moe.SendPrivateMessageResp, error) {
	resp, err := chatbiz.SendPrivateMessage(l.ctx, l.svcCtx.DB, in)
	if err != nil {
		l.Errorf("SendPrivateMessage: %v", err)
	}
	return resp, err
}
