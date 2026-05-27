package logic

import (
	"context"

	chatapp "backend/internal/service/chat"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPrivateMessagesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListPrivateMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPrivateMessagesLogic {
	return &ListPrivateMessagesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListPrivateMessagesLogic) ListPrivateMessages(in *super.ListPrivateMessagesReq) (*super.ListPrivateMessagesResp, error) {
	resp, err := chatapp.New(l.svcCtx.DB).ListPrivateMessages(l.ctx, in)
	if err != nil {
		l.Errorf("ListPrivateMessages: %v", err)
	}
	return resp, err
}
