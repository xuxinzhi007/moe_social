package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// LikeResult 点赞/取消点赞结果。
type LikeResult struct {
	Post      model.Post
	User      model.User
	IsLiked   bool
	DidLike   bool
	LikeCount int
}

// Like 切换帖子点赞状态。
func Like(ctx context.Context, db *gorm.DB, postIDStr, userIDStr string) (LikeResult, error) {
	if db == nil {
		return LikeResult{}, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDStr), 10, 32)
	if err != nil || postID == 0 {
		return LikeResult{}, ErrInvalidPostID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDStr), 10, 32)
	if err != nil || userID == 0 {
		return LikeResult{}, ErrInvalidUserID
	}

	var post model.Post
	if err := db.WithContext(ctx).First(&post, postID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return LikeResult{}, ErrPostNotFound
		}
		return LikeResult{}, err
	}

	var like model.Like
	hasLiked := db.WithContext(ctx).
		Where("target_id = ? AND user_id = ? AND target_type = ?", postID, userID, "post").
		First(&like).Error == nil

	tx := db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return LikeResult{}, tx.Error
	}
	didLike := !hasLiked
	if hasLiked {
		if err := tx.Delete(&like).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.Model(&post).Update("likes", post.Likes-1).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		post.Likes--
	} else {
		newLike := model.Like{TargetID: uint(postID), UserID: uint(userID), TargetType: "post"}
		if err := tx.Create(&newLike).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.Model(&post).Update("likes", post.Likes+1).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		post.Likes++
	}
	if err := tx.Commit().Error; err != nil {
		return LikeResult{}, err
	}

	if err := db.WithContext(ctx).Preload("User").Preload("TopicTags").First(&post, postID).Error; err != nil {
		return LikeResult{}, err
	}

	likedSet := LikedTargetIDSet(db.WithContext(ctx), uint(userID), "post", []uint{uint(postID)})
	isLiked := likedSet[uint(postID)]
	user := post.User
	return LikeResult{
		Post: post, User: user, IsLiked: isLiked, DidLike: didLike, LikeCount: post.Likes,
	}, nil
}
