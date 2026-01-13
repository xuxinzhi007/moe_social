package logic

import (
	"context"
	"strconv"

	"backend/model"
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

// 关注相关服务
func (l *FollowUserLogic) FollowUser(in *super.FollowUserReq) (*super.FollowUserResp, error) {
	l.Debug("关注用户请求:", in)

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

	// 检查是否已经关注（包括被软删除的记录）
	var existingFollow model.Follow
	result := l.svcCtx.DB.Unscoped().Where("follower_id = ? AND following_id = ?", followerID, followingID).First(&existingFollow)

	if result.Error == nil {
		// 记录存在
		if existingFollow.DeletedAt.Time.IsZero() {
			// 已经关注，直接返回成功
			return &super.FollowUserResp{
				Success: true,
			}, nil
		} else {
			// 记录被软删除，恢复关注
			if err := l.svcCtx.DB.Model(&existingFollow).Update("deleted_at", nil).Error; err != nil {
				l.Error("恢复关注关系失败:", err)
				return nil, err
			}
		}
	} else {
		// 创建新关注关系
		follow := model.Follow{
			FollowerID:  uint(followerID),
			FollowingID: uint(followingID),
		}

		// 保存到数据库
		if err := l.svcCtx.DB.Create(&follow).Error; err != nil {
			l.Error("创建关注关系失败:", err)
			return nil, err
		}
	}

	// 触发关注通知
	// TODO: 实现关注通知逻辑

	l.Debug("关注用户成功:", followerID, "关注了", followingID)

	return &super.FollowUserResp{
		Success: true,
	}, nil
}
