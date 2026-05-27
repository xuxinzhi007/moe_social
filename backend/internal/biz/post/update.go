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
func Update(ctx context.Context, db *gorm.DB, in UpdateInput) (UpdateResult, error) {
	if db == nil {
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

	var p model.Post
	if err := db.WithContext(ctx).First(&p, postID).Error; err != nil {
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
	if err := db.WithContext(ctx).Save(&p).Error; err != nil {
		return UpdateResult{}, err
	}

	if in.UpdateTopicTags {
		db.WithContext(ctx).Where("post_id = ?", p.ID).Delete(&model.PostTopic{})
		for _, tag := range in.TopicTags {
			var tt model.TopicTag
			db.WithContext(ctx).Where("name = ?", tag.Name).FirstOrCreate(&tt, model.TopicTag{
				Name: tag.Name, Color: tag.Color,
			})
			db.WithContext(ctx).Create(&model.PostTopic{PostID: p.ID, TopicTagID: tt.ID})
		}
	}

	if err := db.WithContext(ctx).Preload("TopicTags").First(&p, p.ID).Error; err != nil {
		return UpdateResult{}, err
	}

	var user model.User
	_ = db.WithContext(ctx).Select("id, username, email, avatar").First(&user, p.UserID).Error

	var likeCount int64
	db.WithContext(ctx).Model(&model.Like{}).
		Where("target_type = 'post' AND target_id = ?", p.ID).Count(&likeCount)
	var commentCount int64
	db.WithContext(ctx).Model(&model.Comment{}).
		Where("post_id = ? AND deleted_at IS NULL", p.ID).Count(&commentCount)
	p.Likes = int(likeCount)
	p.Comments = int(commentCount)

	likedSet := LikedTargetIDSet(db.WithContext(ctx), uint(userID), "post", []uint{p.ID})
	return UpdateResult{Post: p, User: user, IsLiked: likedSet[p.ID]}, nil
}
