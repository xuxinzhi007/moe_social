package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *UnfollowUserLogic) UnfollowUser(in *super.UnfollowUserReq) (*super.FollowUserResp, error) {
	l.Debug("取消关注请求:", in)
	
	// 转换ID为uint
	followerID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		l.Error("解析关注者ID失败:", err)
		return nil, err
	}
	
	followingID, err := strconv.ParseUint(in.FollowingId, 10, 32)
	if err != nil {
		l.Error("解析被关注者ID失败:", err)
		return nil, err
	}
	
	// 删除关注关系
	result := l.svcCtx.DB.Where("follower_id = ? AND following_id = ?", followerID, followingID).Delete(&model.Follow{})
	if result.Error != nil {
		l.Error("取消关注失败:", result.Error)
		return nil, result.Error
	}
	
	l.Debug("取消关注成功:", followerID, "取消关注了", followingID)
	
	return &super.FollowUserResp{
		Success: true,
	}, nil
}
