package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostCommentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostCommentsLogic {
	return &GetPostCommentsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetPostCommentsLogic) GetPostComments(in *super.GetPostCommentsReq) (*super.GetPostCommentsResp, error) {
	// 解析帖子ID
	postID, err := strconv.ParseUint(in.PostId, 10, 32)
	if err != nil {
		l.Error("解析帖子ID失败:", err)
		return nil, err
	}

	// 设置默认分页参数
	page := in.Page
	pageSize := in.PageSize
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100
	}

	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}

	// 查询评论列表
	var comments []model.Comment
	var total int64

	// 计算总数
	if err := l.svcCtx.DB.Model(&model.Comment{}).Where("post_id = ?", postID).Count(&total).Error; err != nil {
		l.Error("计算评论总数失败:", err)
		return nil, err
	}

	// 查询评论列表，按创建时间倒序排列
	if err := l.svcCtx.DB.Where("post_id = ?", postID).
		Order("created_at DESC").
		Offset(int(offset)).
		Limit(int(pageSize)).
		Find(&comments).Error; err != nil {
		l.Error("查询评论列表失败:", err)
		return nil, err
	}

	// 查询用户信息（批量查询）
	userMap := make(map[uint]model.User)
	if len(comments) > 0 {
		userIDs := make([]uint, 0, len(comments))
		for _, comment := range comments {
			userIDs = append(userIDs, comment.UserID)
		}
		var users []model.User
		l.svcCtx.DB.Where("id IN ?", userIDs).Find(&users)
		for _, user := range users {
			userMap[user.ID] = user
		}
	}

	// 构建响应
	resp := &super.GetPostCommentsResp{
		Comments: make([]*super.Comment, 0, len(comments)),
		Total:    int32(total),
	}

	// 转换为rpc响应格式
	for _, comment := range comments {
		// 获取用户信息
		username := "未知用户"
		avatar := "https://picsum.photos/150"
		if user, ok := userMap[comment.UserID]; ok {
			if user.Username != "" {
				username = user.Username
			} else if user.Email != "" {
				username = user.Email
			}
			if user.Avatar != "" {
				avatar = user.Avatar
			}
		}

		rpcComment := &super.Comment{
			Id:         strconv.FormatUint(uint64(comment.ID), 10),
			PostId:     strconv.FormatUint(uint64(comment.PostID), 10),
			UserId:     strconv.FormatUint(uint64(comment.UserID), 10),
			UserName:   username,
			UserAvatar: avatar,
			Content:    comment.Content,
			Likes:      int32(comment.Likes),
			IsLiked:    false, // 这里需要根据当前用户是否点赞来设置，暂时设为false
			CreatedAt:  comment.CreatedAt.Format("2006-01-02 15:04:05"),
		}

		resp.Comments = append(resp.Comments, rpcComment)
	}

	return resp, nil
}
