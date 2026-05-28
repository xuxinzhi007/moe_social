package commentbiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// CommentStore 评论持久化（P4-D；默认由 internal/data/comment 实现）。
type CommentStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) CommentStore

	GetPost(ctx context.Context, postID uint) (model.Post, error)
	GetUser(ctx context.Context, userID uint) (model.User, error)
	GetUsersByIDs(ctx context.Context, userIDs []uint) ([]model.User, error)

	GetComment(ctx context.Context, commentID uint) (model.Comment, error)
	GetCommentWithUser(ctx context.Context, commentID uint) (model.Comment, error)
	ListCommentsWithUserByIDs(ctx context.Context, ids []uint) ([]model.Comment, error)
	ListCommentsByPost(ctx context.Context, postID uint, offset, limit int) ([]model.Comment, int64, error)

	FindLike(ctx context.Context, targetID, userID uint, targetType string) (model.Like, bool, error)
	HasLiked(ctx context.Context, targetID, userID uint, targetType string) (bool, error)
	PluckLikedTargetIDs(ctx context.Context, userID uint, targetType string, targetIDs []uint) ([]uint, error)

	Begin(ctx context.Context) (CommentTx, error)
}

// CommentTx 评论事务。
type CommentTx interface {
	GetComment(commentID uint) (model.Comment, error)
	CreateComment(comment *model.Comment) error
	UpdatePostComments(postID uint, comments int) error
	CreateNotification(n *model.Notification) error

	DeleteLike(like *model.Like) error
	CreateLike(like *model.Like) error
	UpdateCommentLikes(commentID uint, likes int) error

	Commit() error
	Rollback() error
}
