package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetFollowingsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetFollowingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFollowingsLogic {
	return &GetFollowingsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetFollowingsLogic) GetFollowings(in *super.GetFollowingsReq) (*super.GetFollowingsResp, error) {
	l.Debug("获取关注列表请求:", in)
	
	// 转换用户ID为uint
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		l.Error("解析用户ID失败:", err)
		return &super.GetFollowingsResp{}, err
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
	
	// 查询关注的用户列表
	var follows []model.Follow
	var total int64
	
	// 获取总数
	l.svcCtx.DB.Model(&model.Follow{}).Where("follower_id = ? AND deleted_at IS NULL", userID).Count(&total)
	
	// 分页查询，预加载被关注者信息
	result := l.svcCtx.DB.Preload("Following").Where("follower_id = ? AND deleted_at IS NULL", userID).Offset(int(offset)).Limit(int(pageSize)).Order("created_at DESC").Find(&follows)
	if result.Error != nil {
		l.Error("获取关注列表失败:", result.Error)
		return &super.GetFollowingsResp{}, result.Error
	}
	
	// 转换为RPC响应格式
	respUsers := make([]*super.User, 0, len(follows))
	for _, follow := range follows {
		user := follow.Following
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
	
	l.Debug("获取关注列表成功:", len(respUsers), "个用户，总数:", total)
	
	return &super.GetFollowingsResp{
		Users: respUsers,
		Total: int32(total),
	}, nil
}
