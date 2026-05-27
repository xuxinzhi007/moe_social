package logic

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/pkg/achievement"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type FollowUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFollowUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FollowUserLogic {
	return &FollowUserLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *FollowUserLogic) FollowUser(in *super.FollowUserReq) (*super.FollowUserResp, error) {
	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())
	if err != nil {
		l.Error("解析关注 ID 失败:", err)
		return nil, err
	}
	if err := userbiz.Follow(l.ctx, l.svcCtx.DB, followerID, followingID); err != nil {
		l.Error("关注失败:", err)
		return nil, err
	}
	if _, achErr := achievement.ApplyEventAfterCommit(l.svcCtx.DB, followingID, achievement.Event{Type: achievement.EventNewFollower}); achErr != nil {
		l.Errorf("成就处理失败（关注仍会成功）: %v", achErr)
	}
	return &super.FollowUserResp{Success: true}, nil
}
