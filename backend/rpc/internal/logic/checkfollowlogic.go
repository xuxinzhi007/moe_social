package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckFollowLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckFollowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckFollowLogic {
	return &CheckFollowLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CheckFollowLogic) CheckFollow(in *super.CheckFollowReq) (*super.CheckFollowResp, error) {
	// todo: add your logic here and delete this line

	return &super.CheckFollowResp{}, nil
}
