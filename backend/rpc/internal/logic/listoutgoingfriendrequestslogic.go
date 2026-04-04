package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListOutgoingFriendRequestsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListOutgoingFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListOutgoingFriendRequestsLogic {
	return &ListOutgoingFriendRequestsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListOutgoingFriendRequestsLogic) ListOutgoingFriendRequests(in *super.ListOutgoingFriendRequestsReq) (*super.ListOutgoingFriendRequestsResp, error) {
	return NewFriendRelationLogic(l.ctx, l.svcCtx).ListOutgoingFriendRequests(in)
}
