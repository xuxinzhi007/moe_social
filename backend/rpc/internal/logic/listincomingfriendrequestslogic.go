package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListIncomingFriendRequestsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListIncomingFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListIncomingFriendRequestsLogic {
	return &ListIncomingFriendRequestsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListIncomingFriendRequestsLogic) ListIncomingFriendRequests(in *moe.ListIncomingFriendRequestsReq) (*moe.ListIncomingFriendRequestsResp, error) {
	return NewFriendRelationLogic(l.ctx, l.svcCtx).ListIncomingFriendRequests(in)
}
