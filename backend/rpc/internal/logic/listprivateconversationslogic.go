package logic

import (
	"context"

	chatapp "backend/internal/service/chat"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPrivateConversationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListPrivateConversationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPrivateConversationsLogic {
	return &ListPrivateConversationsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListPrivateConversationsLogic) ListPrivateConversations(in *moe.ListPrivateConversationsReq) (*moe.ListPrivateConversationsResp, error) {
	resp, err := chatapp.New(l.svcCtx.DB).ListPrivateConversations(l.ctx, in)
	if err != nil {
		l.Errorf("ListPrivateConversations: %v", err)
	}
	return resp, err
}
