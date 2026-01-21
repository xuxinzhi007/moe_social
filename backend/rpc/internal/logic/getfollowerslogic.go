package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetFollowersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetFollowersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFollowersLogic {
	return &GetFollowersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetFollowersLogic) GetFollowers(in *super.GetFollowersReq) (*super.GetFollowersResp, error) {
	l.Debug("获取粉丝列表请求:", in)
	
	// 转换用户ID为uint
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		l.Error("解析用户ID失败:", err)
		return &super.GetFollowersResp{}, err
	}
	
	// 计算分页参数
	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (page - 1) * pageSize
	
	// 查询粉丝列表
	var follows []model.Follow
	var total int64

	// 获取总数
	l.svcCtx.DB.Model(&model.Follow{}).Where("following_id = ? AND deleted_at IS NULL", userID).Count(&total)

	// 分页查询关注记录
	result := l.svcCtx.DB.Where("following_id = ? AND deleted_at IS NULL", userID).Offset(int(offset)).Limit(int(pageSize)).Order("created_at DESC").Find(&follows)
	if result.Error != nil {
		l.Error("获取粉丝列表失败:", result.Error)
		return &super.GetFollowersResp{}, result.Error
	}

	// 提取follower_id列表
	followerIDs := make([]uint, len(follows))
	for i, follow := range follows {
		followerIDs[i] = follow.FollowerID
	}

	// 查询用户信息
	var users []model.User
	if len(followerIDs) > 0 {
		if err := l.svcCtx.DB.Where("id IN ?", followerIDs).Find(&users).Error; err != nil {
			l.Error("查询粉丝用户信息失败:", err)
			return &super.GetFollowersResp{}, err
		}
	}

	// 创建用户ID到用户信息的映射
	userMap := make(map[uint]model.User)
	for _, user := range users {
		userMap[user.ID] = user
	}

	// 转换为RPC响应格式
	respUsers := make([]*super.User, 0, len(follows))
	for _, follow := range follows {
		user, exists := userMap[follow.FollowerID]
		if !exists {
			continue // 如果用户不存在，跳过
		}
		// 处理可能为 nil 的时间字段
		var vipExpiresAt string
		if user.VipEndAt != nil {
			vipExpiresAt = user.VipEndAt.Format("2006-01-02 15:04:05")
		} else {
			vipExpiresAt = ""
		}
		
		respUser := &super.User{
			Id:           strconv.Itoa(int(user.ID)),
			Username:     user.Username,
			Email:        user.Email,
			Avatar:       user.Avatar,
			CreatedAt:    user.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:    user.UpdatedAt.Format("2006-01-02 15:04:05"),
			IsVip:        user.IsVip,
			VipExpiresAt: vipExpiresAt,
			AutoRenew:    user.AutoRenew,
			Balance:      float32(user.Balance),
		}
		respUsers = append(respUsers, respUser)
	}
	
	l.Debug("获取粉丝列表成功:", len(respUsers), "个粉丝，总数:", total)
	
	return &super.GetFollowersResp{
		Users: respUsers,
		Total: int32(total),
	}, nil
}
