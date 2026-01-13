package logic

import (
	"context"

	"backend/model"
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
	l.Debug("检查关注状态请求:", in)

	// 解析参数
	var count int64
	result := l.svcCtx.DB.Model(&model.Follow{}).Where("follower_id = ? AND following_id = ? AND deleted_at IS NULL", in.FollowerId, in.FollowingId).Count(&count)
	if result.Error != nil {
		l.Error("检查关注状态失败:", result.Error)
		return nil, result.Error
	}

	l.Debug("检查关注状态成功:", in.FollowerId, "关注了", in.FollowingId, "?", count > 0)

	return &super.CheckFollowResp{
		IsFollowing: count > 0,
	}, nil
}
