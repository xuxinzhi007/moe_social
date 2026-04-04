package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *ListIncomingFriendRequestsLogic) ListIncomingFriendRequests(in *super.ListIncomingFriendRequestsReq) (*super.ListIncomingFriendRequestsResp, error) {
	return NewFriendRelationLogic(l.ctx, l.svcCtx).ListIncomingFriendRequests(in)
}
