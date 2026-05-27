package logic

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type JoinGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewJoinGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *JoinGroupLogic {
	return &JoinGroupLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *JoinGroupLogic) JoinGroup(in *super.JoinGroupReq) (*super.JoinGroupResp, error) {
	return communityapp.New(l.svcCtx.DB).JoinGroup(l.ctx, in)
}
