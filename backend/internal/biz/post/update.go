package postbiz

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// UpdateInput 更新帖子参数。
type UpdateInput struct {
	PostID           string
	UserID           string
	Content          string
	Images           []string
	TopicTags        []TopicTagInput
	HandDrawCard     string
	HandDrawThumbURL string
	UpdateImages     bool
	UpdateTopicTags  bool
}

// UpdateResult 更新帖子结果。
type UpdateResult struct {
	Post    model.Post
	User    model.User
	IsLiked bool
}

// Update 更新帖子（仅作者）。
func Update(ctx context.Context, st PostStore, in UpdateInput) (UpdateResult, error) {
	if st == nil {
		return UpdateResult{}, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(in.PostID), 10, 64)
	if err != nil || postID == 0 {
		return UpdateResult{}, ErrInvalidPostID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(in.UserID), 10, 64)
	if err != nil || userID == 0 {
		return UpdateResult{}, ErrInvalidUserID
	}

	st = st.WithContext(ctx)
	p, err := st.GetPost(ctx, uint(postID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return UpdateResult{}, ErrPostNotFound
		}
		return UpdateResult{}, err
	}
	if uint64(p.UserID) != userID {
		return UpdateResult{}, ErrNotPostOwner
	}

	if in.Content != "" {
		p.Content = in.Content
	}
	if in.UpdateImages {
		if len(in.Images) == 0 {
			p.Images = "[]"
		} else {
			imagesJSON, err := json.Marshal(in.Images)
			if err != nil {
				return UpdateResult{}, err
			}
			p.Images = string(imagesJSON)
		}
	}
	if in.HandDrawCard != "" {
		p.HandDrawCard = in.HandDrawCard
	}
	if in.HandDrawThumbURL != "" {
		p.HandDrawThumbURL = in.HandDrawThumbURL
	}
	if err := st.SavePost(ctx, &p); err != nil {
		return UpdateResult{}, err
	}

	if in.UpdateTopicTags {
		st.DeletePostTopics(ctx, p.ID)
		for _, tag := range in.TopicTags {
			tt, _ := st.FirstOrCreateTopicTag(ctx, tag.Name, tag.Color)
			_ = st.CreatePostTopic(ctx, p.ID, tt.ID)
		}
	}

	p, err = st.GetPostWithTopicTags(ctx, p.ID)
	if err != nil {
		return UpdateResult{}, err
	}

	user, _ := st.GetUserSelect(ctx, p.UserID, "id, username, email, avatar")

	likeCount, _ := st.CountLikesForPost(ctx, p.ID)
	commentCount, _ := st.CountCommentsForPost(ctx, p.ID)
	p.Likes = int(likeCount)
	p.Comments = int(commentCount)

	likedSet := LikedTargetIDSet(ctx, st, uint(userID), "post", []uint{p.ID})
	return UpdateResult{Post: p, User: user, IsLiked: likedSet[p.ID]}, nil
}
