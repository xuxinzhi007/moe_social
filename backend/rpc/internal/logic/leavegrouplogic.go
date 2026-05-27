package logic

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LeaveGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLeaveGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LeaveGroupLogic {
	return &LeaveGroupLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *LeaveGroupLogic) LeaveGroup(in *super.LeaveGroupReq) (*super.LeaveGroupResp, error) {
	return communityapp.New(l.svcCtx.DB).LeaveGroup(l.ctx, in)
}
