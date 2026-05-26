package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
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

	var viewerUID uint
	if in.ViewerUserId != "" {
		if v, err := strconv.ParseUint(in.ViewerUserId, 10, 32); err == nil {
			viewerUID = uint(v)
		}
	}

	feedMode := strings.ToLower(strings.TrimSpace(in.FeedMode))

	var topicTagID uint
	if strings.TrimSpace(in.TopicTagId) != "" {
		if v, err := strconv.ParseUint(strings.TrimSpace(in.TopicTagId), 10, 32); err == nil {
			topicTagID = uint(v)
		}
	}

	var authorUID uint
	if strings.TrimSpace(in.AuthorUserId) != "" {
		if v, err := strconv.ParseUint(strings.TrimSpace(in.AuthorUserId), 10, 32); err == nil {
			authorUID = uint(v)
		}
	}

	listQuery := l.svcCtx.DB.Model(&model.Post{}).Scopes(moderationVisibleScope(viewerUID))

	if topicTagID > 0 {
		sub := l.svcCtx.DB.Model(&model.PostTopic{}).Select("post_id").Where("topic_tag_id = ?", topicTagID)
		listQuery = listQuery.Where("id IN (?)", sub)
	}

	if authorUID > 0 {
		listQuery = listQuery.Where("user_id = ?", authorUID)
	} else if feedMode == "following" {
		if viewerUID == 0 {
			listQuery = listQuery.Where("1 = 0")
		} else {
			sub := l.svcCtx.DB.Model(&model.Follow{}).Select("following_id").Where("follower_id = ?", viewerUID)
			listQuery = listQuery.Where("user_id = ? OR user_id IN (?)", viewerUID, sub)
		}
	}

	switch feedMode {
	case "hot":
		listQuery = listQuery.Order("(likes * 2 + comments) DESC").Order("created_at DESC").Order("id DESC")
	default:
		listQuery = listQuery.Order("created_at DESC").Order("id DESC")
	}

	var posts []model.Post
	var total int64

	if err := listQuery.Session(&gorm.Session{}).Count(&total).Error; err != nil {
		return nil, err
	}

	if err := listQuery.Preload("TopicTags").Offset(int(offset)).Limit(int(pageSize)).Find(&posts).Error; err != nil {
		return nil, err
	}

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

	resp := &super.GetPostsResp{
		Posts: make([]*super.Post, 0, len(posts)),
		Total: int32(total),
	}

	postIDs := make([]uint, 0, len(posts))
	for _, p := range posts {
		postIDs = append(postIDs, p.ID)
	}
	likedPosts := LikedTargetIDSet(l.svcCtx.DB, viewerUID, "post", postIDs)

	for _, post := range posts {
		user := userMap[post.UserID]
		rpcPost := buildSuperPost(post, user, likedPosts[post.ID])

		resp.Posts = append(resp.Posts, rpcPost)
	}

	return resp, nil
}
