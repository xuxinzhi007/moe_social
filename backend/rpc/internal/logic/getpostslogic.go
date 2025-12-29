package logic

import (
	"context"
	"encoding/json"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostsLogic {
	return &GetPostsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 帖子相关服务
func (l *GetPostsLogic) GetPosts(in *super.GetPostsReq) (*super.GetPostsResp, error) {
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

	// 查询帖子列表
	var posts []model.Post
	var total int64

	// 计算总数
	if err := l.svcCtx.DB.Model(&model.Post{}).Count(&total).Error; err != nil {
		return nil, err
	}

	// 查询帖子
	if err := l.svcCtx.DB.Order("created_at DESC").Offset(int(offset)).Limit(int(pageSize)).Find(&posts).Error; err != nil {
		return nil, err
	}

	// 查询用户信息（批量查询）
	userMap := make(map[uint]model.User)
	if len(posts) > 0 {
		userIDs := make([]uint, 0, len(posts))
		for _, post := range posts {
			userIDs = append(userIDs, post.UserID)
		}
		var users []model.User
		l.svcCtx.DB.Where("id IN ?", userIDs).Find(&users)
		for _, user := range users {
			userMap[user.ID] = user
		}
	}

	// 构建响应
	resp := &super.GetPostsResp{
		Posts: make([]*super.Post, 0, len(posts)),
		Total: int32(total),
	}

	// 转换为rpc响应格式
	for _, post := range posts {
		// 处理图片数组
		var images []string
		if post.Images != "" {
			json.Unmarshal([]byte(post.Images), &images)
		}

		// 获取用户信息
		username := "未知用户"
		avatar := "https://via.placeholder.com/150"
		if user, ok := userMap[post.UserID]; ok {
			if user.Username != "" {
				username = user.Username
			} else if user.Email != "" {
				username = user.Email
			}
			if user.Avatar != "" {
				avatar = user.Avatar
			}
		}

		// 构建Post对象
		rpcPost := &super.Post{
			Id:         strconv.FormatUint(uint64(post.ID), 10),
			UserId:     strconv.FormatUint(uint64(post.UserID), 10),
			UserName:   username,
			UserAvatar: avatar,
			Content:    post.Content,
			Images:     images,
			Likes:      int32(post.Likes),
			Comments:   int32(post.Comments),
			IsLiked:    false,
			CreatedAt:  post.CreatedAt.Format("2006-01-02 15:04:05"),
		}

		resp.Posts = append(resp.Posts, rpcPost)
	}

	return resp, nil
}
