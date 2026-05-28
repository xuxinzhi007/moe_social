package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListFriendRequestsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListFriendRequestsLogic {
	return &AdminListFriendRequestsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListFriendRequestsLogic) AdminListFriendRequests(in *super.AdminListFriendRequestsReq) (*super.AdminListFriendRequestsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListFriendRequests(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
