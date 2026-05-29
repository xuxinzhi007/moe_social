package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	postv1 "backend/api/post/v1"
	moebiz "backend/internal/biz/moe"
	moedata "backend/internal/data/moe"
	"backend/model"

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
func Search(ctx context.Context, st PostStore, in SearchInput) (*postv1.MoeSearchPostsReply, error) {
	if st == nil {
		return nil, gorm.ErrInvalidDB
	}
	hits, err := moebiz.SearchPosts(ctx, moedata.NewStore(st.Raw()), moebiz.SearchPostsInput{
		Query:        in.Query,
		ViewerUserID: uint(in.ViewerUserID),
		MoodTag:      in.MoodTag,
		TopicTagID:   uint(in.TopicTagID),
		Limit:        int(in.Limit),
	})
	if err != nil {
		return nil, err
	}
	out := &postv1.MoeSearchPostsReply{Total: int32(len(hits))}
	for _, h := range hits {
		out.Items = append(out.Items, &postv1.MoeSearchPostHit{
			PostId: h.PostID, UserId: h.UserID, UserName: h.UserName,
			Content: h.Content, Snippet: h.Snippet, MoodTag: h.MoodTag,
			Likes: int32(h.Likes), Comments: int32(h.Comments), CreatedAt: h.CreatedAt,
			Score: h.Score, ScoreReason: h.ScoreReason,
		})
	}
	return out, nil
}

// GetByID 单帖详情。
func GetByID(ctx context.Context, st PostStore, postIDRaw, viewerUserIDRaw string) (*postv1.Post, error) {
	if st == nil {
		return nil, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDRaw), 10, 32)
	if err != nil || postID == 0 {
		return nil, ErrInvalidPostID
	}
	st = st.WithContext(ctx)
	post, err := st.GetPostWithTopicTags(ctx, uint(postID))
	if err != nil {
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
	user, err := st.GetUser(ctx, post.UserID)
	if err != nil {
		return nil, err
	}
	isLiked := false
	if viewerUID > 0 {
		liked := LikedTargetIDSet(ctx, st, viewerUID, "post", []uint{post.ID})
		isLiked = liked[post.ID]
	}
	return BuildPostV1ForDetail(post, user, isLiked), nil
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
func List(ctx context.Context, st PostStore, f ListFilter) ([]*postv1.Post, int32, error) {
	if st == nil {
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

	st = st.WithContext(ctx)
	posts, total, err := st.ListPosts(ctx, ListPostsFilter{
		Offset: offset, Limit: int(pageSize), ViewerUID: viewerUID,
		TopicTagID: topicTagID, AuthorUID: authorUID, FeedMode: feedMode,
	})
	if err != nil {
		return nil, 0, err
	}

	userMap := map[uint]model.User{}
	if len(posts) > 0 {
		userIDs := make([]uint, 0, len(posts))
		for _, post := range posts {
			userIDs = append(userIDs, post.UserID)
		}
		users, _ := st.GetUsersByIDs(ctx, userIDs)
		for _, user := range users {
			userMap[user.ID] = user
		}
	}
	postIDs := make([]uint, 0, len(posts))
	for _, p := range posts {
		postIDs = append(postIDs, p.ID)
	}
	likedPosts := LikedTargetIDSet(ctx, st, viewerUID, "post", postIDs)
	out := make([]*postv1.Post, 0, len(posts))
	for _, post := range posts {
		out = append(out, BuildPostV1ForList(post, userMap[post.UserID], likedPosts[post.ID]))
	}
	return out, int32(total), nil
}
