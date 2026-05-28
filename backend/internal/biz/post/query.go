package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	moebiz "backend/internal/biz/moe"
	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// SearchInput 帖子检索参数。
type SearchInput struct {
	Query        string
	Limit        int32
	ViewerUserID uint64
	MoodTag      string
	TopicTagID   uint64
}

// Search 关键词检索帖子。
func Search(ctx context.Context, db *gorm.DB, in SearchInput) (*moe.MoeSearchPostsResp, error) {
	hits, err := moebiz.SearchPosts(ctx, db, moebiz.SearchPostsInput{
		Query:        in.Query,
		ViewerUserID: uint(in.ViewerUserID),
		MoodTag:      in.MoodTag,
		TopicTagID:   uint(in.TopicTagID),
		Limit:        int(in.Limit),
	})
	if err != nil {
		return nil, err
	}
	out := &moe.MoeSearchPostsResp{Total: int32(len(hits))}
	for _, h := range hits {
		out.Items = append(out.Items, &moe.MoeSearchPostHit{
			PostId: h.PostID, UserId: h.UserID, UserName: h.UserName,
			Content: h.Content, Snippet: h.Snippet, MoodTag: h.MoodTag,
			Likes: int32(h.Likes), Comments: int32(h.Comments), CreatedAt: h.CreatedAt,
			Score: h.Score, ScoreReason: h.ScoreReason,
		})
	}
	return out, nil
}

// GetByID 单帖详情。
func GetByID(ctx context.Context, db *gorm.DB, postIDRaw, viewerUserIDRaw string) (*moe.Post, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDRaw), 10, 32)
	if err != nil || postID == 0 {
		return nil, ErrInvalidPostID
	}
	var post model.Post
	if err := db.WithContext(ctx).Preload("TopicTags").Where("id = ?", postID).First(&post).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPostNotFound
		}
		return nil, err
	}
	var viewerUID uint
	if viewerUserIDRaw != "" {
		if v, e := strconv.ParseUint(viewerUserIDRaw, 10, 32); e == nil {
			viewerUID = uint(v)
		}
	}
	ms := moderationStatusOrDefault(post.ModerationStatus)
	if ms == "rejected" {
		return nil, ErrPostNotFound
	}
	if ms == "pending" && post.UserID != viewerUID {
		return nil, ErrPostNotFound
	}
	var user model.User
	if err := db.WithContext(ctx).Where("id = ?", post.UserID).First(&user).Error; err != nil {
		return nil, err
	}
	isLiked := false
	if viewerUID > 0 {
		liked := LikedTargetIDSet(db, viewerUID, "post", []uint{post.ID})
		isLiked = liked[post.ID]
	}
	return BuildProtoPost(post, user, isLiked), nil
}

// ListFilter 帖子列表筛选。
type ListFilter struct {
	Page         int32
	PageSize     int32
	ViewerUserID string
	FeedMode     string
	TopicTagID   string
	AuthorUserID string
}

// List 帖子 feed 列表。
func List(ctx context.Context, db *gorm.DB, f ListFilter) ([]*moe.Post, int32, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page, pageSize := f.Page, f.PageSize
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100
	}
	offset := int((page - 1) * pageSize)

	var viewerUID uint
	if f.ViewerUserID != "" {
		if v, err := strconv.ParseUint(f.ViewerUserID, 10, 32); err == nil {
			viewerUID = uint(v)
		}
	}
	feedMode := strings.ToLower(strings.TrimSpace(f.FeedMode))

	var topicTagID uint
	if strings.TrimSpace(f.TopicTagID) != "" {
		if v, err := strconv.ParseUint(strings.TrimSpace(f.TopicTagID), 10, 32); err == nil {
			topicTagID = uint(v)
		}
	}
	var authorUID uint
	if strings.TrimSpace(f.AuthorUserID) != "" {
		if v, err := strconv.ParseUint(strings.TrimSpace(f.AuthorUserID), 10, 32); err == nil {
			authorUID = uint(v)
		}
	}

	listQuery := db.WithContext(ctx).Model(&model.Post{}).Scopes(ModerationVisibleScope(viewerUID))
	if topicTagID > 0 {
		sub := db.Model(&model.PostTopic{}).Select("post_id").Where("topic_tag_id = ?", topicTagID)
		listQuery = listQuery.Where("id IN (?)", sub)
	}
	if authorUID > 0 {
		listQuery = listQuery.Where("user_id = ?", authorUID)
	} else if feedMode == "following" {
		if viewerUID == 0 {
			listQuery = listQuery.Where("1 = 0")
		} else {
			sub := db.Model(&model.Follow{}).Select("following_id").Where("follower_id = ?", viewerUID)
			listQuery = listQuery.Where("user_id = ? OR user_id IN (?)", viewerUID, sub)
		}
	}
	switch feedMode {
	case "hot":
		listQuery = listQuery.Order("(likes * 2 + comments) DESC").Order("created_at DESC").Order("id DESC")
	default:
		listQuery = listQuery.Order("created_at DESC").Order("id DESC")
	}

	var total int64
	if err := listQuery.Session(&gorm.Session{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var posts []model.Post
	if err := listQuery.Preload("TopicTags").Offset(offset).Limit(int(pageSize)).Find(&posts).Error; err != nil {
		return nil, 0, err
	}
	userMap := map[uint]model.User{}
	if len(posts) > 0 {
		userIDs := make([]uint, 0, len(posts))
		for _, post := range posts {
			userIDs = append(userIDs, post.UserID)
		}
		var users []model.User
		db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users)
		for _, user := range users {
			userMap[user.ID] = user
		}
	}
	postIDs := make([]uint, 0, len(posts))
	for _, p := range posts {
		postIDs = append(postIDs, p.ID)
	}
	likedPosts := LikedTargetIDSet(db, viewerUID, "post", postIDs)
	out := make([]*moe.Post, 0, len(posts))
	for _, post := range posts {
		out = append(out, BuildProtoPost(post, userMap[post.UserID], likedPosts[post.ID]))
	}
	return out, int32(total), nil
}
