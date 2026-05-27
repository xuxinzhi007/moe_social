package commentbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// LikeResult 评论点赞结果。
type LikeResult struct {
	Comment model.Comment
	User    model.User
	IsLiked bool
}

// Like 切换评论点赞状态。
func Like(ctx context.Context, db *gorm.DB, commentIDStr, userIDStr string) (LikeResult, error) {
	if db == nil {
		return LikeResult{}, gorm.ErrInvalidDB
	}
	commentID, err := strconv.ParseUint(strings.TrimSpace(commentIDStr), 10, 32)
	if err != nil || commentID == 0 {
		return LikeResult{}, ErrInvalidCommentID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDStr), 10, 32)
	if err != nil || userID == 0 {
		return LikeResult{}, ErrInvalidUserID
	}

	var comment model.Comment
	if err := db.WithContext(ctx).First(&comment, commentID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return LikeResult{}, ErrCommentNotFound
		}
		return LikeResult{}, err
	}

	var like model.Like
	hasLiked := db.WithContext(ctx).
		Where("target_id = ? AND user_id = ? AND target_type = ?", commentID, userID, "comment").
		First(&like).Error == nil

	tx := db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return LikeResult{}, tx.Error
	}
	if hasLiked {
		if err := tx.Delete(&like).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.Model(&comment).Update("likes", comment.Likes-1).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		comment.Likes--
	} else {
		newLike := model.Like{TargetID: uint(commentID), UserID: uint(userID), TargetType: "comment"}
		if err := tx.Create(&newLike).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		if err := tx.Model(&comment).Update("likes", comment.Likes+1).Error; err != nil {
			tx.Rollback()
			return LikeResult{}, err
		}
		comment.Likes++
	}
	if err := tx.Commit().Error; err != nil {
		return LikeResult{}, err
	}

	if err := db.WithContext(ctx).Preload("User").First(&comment, commentID).Error; err != nil {
		return LikeResult{}, err
	}

	var currentLike model.Like
	isLiked := db.WithContext(ctx).
		Where("target_id = ? AND user_id = ? AND target_type = ?", commentID, userID, "comment").
		First(&currentLike).Error == nil

	return LikeResult{Comment: comment, User: comment.User, IsLiked: isLiked}, nil
}
