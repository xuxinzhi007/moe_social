// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AcceptFriendRequestLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAcceptFriendRequestLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AcceptFriendRequestLogic {
	return &AcceptFriendRequestLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AcceptFriendRequestLogic) AcceptFriendRequest(req *types.FriendRequestActionReq) (resp *types.FriendRequestActionResp, err error) {
	// todo: add your logic here and delete this line

	return
}
