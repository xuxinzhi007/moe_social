package commentbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// CreateInput 创建评论参数。
type CreateInput struct {
	PostID   string
	UserID   string
	Content  string
	ParentID string
}

// CreateResult 创建评论结果。
type CreateResult struct {
	Comment       model.Comment
	ReplyToUserName string
}

// Create 创建评论并发送通知。
func Create(ctx context.Context, db *gorm.DB, in CreateInput) (CreateResult, error) {
	if db == nil {
		return CreateResult{}, gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(in.PostID), 10, 32)
	if err != nil || postID == 0 {
		return CreateResult{}, ErrInvalidPostID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(in.UserID), 10, 32)
	if err != nil || userID == 0 {
		return CreateResult{}, ErrInvalidUserID
	}

	var post model.Post
	if err := db.WithContext(ctx).First(&post, postID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CreateResult{}, ErrPostNotFound
		}
		return CreateResult{}, err
	}
	var user model.User
	if err := db.WithContext(ctx).First(&user, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CreateResult{}, ErrUserNotFound
		}
		return CreateResult{}, err
	}

	tx := db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return CreateResult{}, tx.Error
	}
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	var parentID uint
	if pid := strings.TrimSpace(in.ParentID); pid != "" {
		parsed, err := strconv.ParseUint(pid, 10, 32)
		if err != nil || parsed == 0 {
			tx.Rollback()
			return CreateResult{}, ErrInvalidParentID
		}
		var parent model.Comment
		if err := tx.First(&parent, parsed).Error; err != nil {
			tx.Rollback()
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return CreateResult{}, ErrParentNotFound
			}
			return CreateResult{}, err
		}
		if parent.PostID != uint(postID) {
			tx.Rollback()
			return CreateResult{}, ErrParentMismatch
		}
		parentID = uint(parsed)
	}

	comment := model.Comment{
		PostID: uint(postID), ParentID: parentID, UserID: uint(userID), Content: in.Content,
	}
	if err := tx.Create(&comment).Error; err != nil {
		tx.Rollback()
		return CreateResult{}, err
	}
	if err := tx.Model(&post).Update("comments", post.Comments+1).Error; err != nil {
		tx.Rollback()
		return CreateResult{}, err
	}

	notifyContent := in.Content
	if len(notifyContent) > 200 {
		notifyContent = notifyContent[:200]
	}
	if parentID > 0 {
		var parent model.Comment
		if err := tx.First(&parent, parentID).Error; err == nil && parent.UserID != uint(userID) {
			_ = tx.Create(&model.Notification{
				UserID: parent.UserID, SenderID: uint(userID), Type: 2,
				PostID: uint(postID), Content: notifyContent, IsRead: false,
			}).Error
		}
	} else if uint(userID) != post.UserID {
		_ = tx.Create(&model.Notification{
			UserID: post.UserID, SenderID: uint(userID), Type: 2,
			PostID: uint(postID), Content: notifyContent, IsRead: false,
		}).Error
	}
	if err := tx.Commit().Error; err != nil {
		return CreateResult{}, err
	}

	replyToName := ""
	if comment.ParentID > 0 {
		var parent model.Comment
		if err := db.WithContext(ctx).Preload("User").First(&parent, comment.ParentID).Error; err == nil {
			if parent.User.Username != "" {
				replyToName = parent.User.Username
			}
		}
	}
	if err := db.WithContext(ctx).Preload("User").First(&comment, comment.ID).Error; err != nil {
		return CreateResult{}, err
	}
	return CreateResult{Comment: comment, ReplyToUserName: replyToName}, nil
}
