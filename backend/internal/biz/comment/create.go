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
	Comment         model.Comment
	ReplyToUserName string
}

// Create 创建评论并发送通知。
func Create(ctx context.Context, st CommentStore, in CreateInput) (CreateResult, error) {
	if st == nil {
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

	st = st.WithContext(ctx)
	post, err := st.GetPost(ctx, uint(postID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CreateResult{}, ErrPostNotFound
		}
		return CreateResult{}, err
	}
	if _, err := st.GetUser(ctx, uint(userID)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CreateResult{}, ErrUserNotFound
		}
		return CreateResult{}, err
	}

	tx, err := st.Begin(ctx)
	if err != nil {
		return CreateResult{}, err
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
		parent, err := tx.GetComment(uint(parsed))
		if err != nil {
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
	if err := tx.CreateComment(&comment); err != nil {
		tx.Rollback()
		return CreateResult{}, err
	}
	if err := tx.UpdatePostComments(post.ID, post.Comments+1); err != nil {
		tx.Rollback()
		return CreateResult{}, err
	}

	notifyContent := in.Content
	if len(notifyContent) > 200 {
		notifyContent = notifyContent[:200]
	}
	if parentID > 0 {
		parent, err := tx.GetComment(parentID)
		if err == nil && parent.UserID != uint(userID) {
			_ = tx.CreateNotification(&model.Notification{
				UserID: parent.UserID, SenderID: uint(userID), Type: 2,
				PostID: uint(postID), Content: notifyContent, IsRead: false,
			})
		}
	} else if uint(userID) != post.UserID {
		_ = tx.CreateNotification(&model.Notification{
			UserID: post.UserID, SenderID: uint(userID), Type: 2,
			PostID: uint(postID), Content: notifyContent, IsRead: false,
		})
	}
	if err := tx.Commit(); err != nil {
		return CreateResult{}, err
	}

	replyToName := ""
	if comment.ParentID > 0 {
		parent, err := st.GetCommentWithUser(ctx, comment.ParentID)
		if err == nil && parent.User.Username != "" {
			replyToName = parent.User.Username
		}
	}
	comment, err = st.GetCommentWithUser(ctx, comment.ID)
	if err != nil {
		return CreateResult{}, err
	}
	return CreateResult{Comment: comment, ReplyToUserName: replyToName}, nil
}
