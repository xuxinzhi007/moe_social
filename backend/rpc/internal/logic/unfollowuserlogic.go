package logic

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UnfollowUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUnfollowUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UnfollowUserLogic {
	return &UnfollowUserLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UnfollowUserLogic) UnfollowUser(in *moe.UnfollowUserReq) (*moe.FollowUserResp, error) {
	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())
	if err != nil {
		l.Error("解析关注 ID 失败:", err)
		return nil, err
	}
	if err := userbiz.Unfollow(l.ctx, l.svcCtx.UserStore(), followerID, followingID); err != nil {
		l.Error("取消关注失败:", err)
		return nil, err
	}
	return &moe.FollowUserResp{Success: true}, nil
}
