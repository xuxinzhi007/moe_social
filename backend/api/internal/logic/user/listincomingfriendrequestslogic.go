// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package user

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListIncomingFriendRequestsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListIncomingFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListIncomingFriendRequestsLogic {
	return &ListIncomingFriendRequestsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListIncomingFriendRequestsLogic) ListIncomingFriendRequests(req *types.FriendUserPathReq) (resp *types.ListFriendRequestsResp, err error) {
	// todo: add your logic here and delete this line

	return
}
