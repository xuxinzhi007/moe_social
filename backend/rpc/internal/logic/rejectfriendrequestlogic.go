package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type RejectFriendRequestLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRejectFriendRequestLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RejectFriendRequestLogic {
	return &RejectFriendRequestLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *RejectFriendRequestLogic) RejectFriendRequest(in *super.RejectFriendRequestReq) (*super.RejectFriendRequestResp, error) {
	return NewFriendRelationLogic(l.ctx, l.svcCtx).RejectFriendRequest(in)
}
