package logic

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

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

func (l *CheckFollowLogic) CheckFollow(in *moe.CheckFollowReq) (*moe.CheckFollowResp, error) {
	ok, err := userbiz.IsFollowingByStringID(l.ctx, l.svcCtx.DB, in.GetFollowerId(), in.GetFollowingId())
	if err != nil {
		l.Error("检查关注状态失败:", err)
		return nil, err
	}
	return &moe.CheckFollowResp{IsFollowing: ok}, nil
}
