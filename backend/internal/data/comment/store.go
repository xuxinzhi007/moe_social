package commentdata

import (
	"context"
	"errors"

	commentbiz "backend/internal/biz/comment"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.CommentStore（P4-D）。
func NewStore(db *gorm.DB) commentbiz.CommentStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) commentbiz.CommentStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) GetPost(ctx context.Context, postID uint) (model.Post, error) {
	var post model.Post
	err := s.db.WithContext(ctx).First(&post, postID).Error
	return post, err
}

func (s *store) GetUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *store) GetUsersByIDs(ctx context.Context, userIDs []uint) ([]model.User, error) {
	var users []model.User
	if len(userIDs) == 0 {
		return users, nil
	}
	err := s.db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users).Error
	return users, err
}

func (s *store) ListAcceptedFriendsByUsernames(ctx context.Context, actorID uint, usernames []string) ([]model.User, error) {
	if actorID == 0 || len(usernames) == 0 {
		return nil, nil
	}
	var rels []model.FriendRequest
	err := s.db.WithContext(ctx).
		Where("status = ? AND (from_user_id = ? OR to_user_id = ?)", "accepted", actorID, actorID).
		Find(&rels).Error
	if err != nil {
		return nil, err
	}
	ids := make([]uint, 0, len(rels))
	seen := make(map[uint]struct{}, len(rels))
	for _, rel := range rels {
		other := rel.FromUserID
		if other == actorID {
			other = rel.ToUserID
		}
		if other == 0 || other == actorID {
			continue
		}
		if _, ok := seen[other]; ok {
			continue
		}
		seen[other] = struct{}{}
		ids = append(ids, other)
	}
	if len(ids) == 0 {
		return nil, nil
	}
	var users []model.User
	err = s.db.WithContext(ctx).Where("id IN ? AND username IN ?", ids, usernames).Find(&users).Error
	return users, err
}

func (s *store) GetComment(ctx context.Context, commentID uint) (model.Comment, error) {
	var comment model.Comment
	err := s.db.WithContext(ctx).First(&comment, commentID).Error
	return comment, err
}

func (s *store) GetCommentWithUser(ctx context.Context, commentID uint) (model.Comment, error) {
	var comment model.Comment
	err := s.db.WithContext(ctx).Preload("User").First(&comment, commentID).Error
	return comment, err
}

func (s *store) ListCommentsWithUserByIDs(ctx context.Context, ids []uint) ([]model.Comment, error) {
	var comments []model.Comment
	if len(ids) == 0 {
		return comments, nil
	}
	err := s.db.WithContext(ctx).Preload("User").Where("id IN ?", ids).Find(&comments).Error
	return comments, err
}

func (s *store) ListCommentsByPost(ctx context.Context, postID uint, offset, limit int) ([]model.Comment, int64, error) {
	var total int64
	if err := s.db.WithContext(ctx).Model(&model.Comment{}).Where("post_id = ?", postID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var comments []model.Comment
	err := s.db.WithContext(ctx).Where("post_id = ?", postID).
		Order("created_at ASC").Offset(offset).Limit(limit).Find(&comments).Error
	return comments, total, err
}

func (s *store) FindLike(ctx context.Context, targetID, userID uint, targetType string) (model.Like, bool, error) {
	var like model.Like
	err := s.db.WithContext(ctx).
		Where("target_id = ? AND user_id = ? AND target_type = ?", targetID, userID, targetType).
		First(&like).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.Like{}, false, nil
	}
	return like, err == nil, err
}

func (s *store) HasLiked(ctx context.Context, targetID, userID uint, targetType string) (bool, error) {
	_, ok, err := s.FindLike(ctx, targetID, userID, targetType)
	return ok, err
}

func (s *store) PluckLikedTargetIDs(ctx context.Context, userID uint, targetType string, targetIDs []uint) ([]uint, error) {
	if userID == 0 || len(targetIDs) == 0 {
		return nil, nil
	}
	var found []uint
	err := s.db.WithContext(ctx).Model(&model.Like{}).
		Where("user_id = ? AND target_type = ? AND target_id IN ?", userID, targetType, targetIDs).
		Pluck("target_id", &found).Error
	return found, err
}

func (s *store) Begin(ctx context.Context) (commentbiz.CommentTx, error) {
	tx := s.db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}
	return &txWrapper{tx: tx}, nil
}

type txWrapper struct {
	tx *gorm.DB
}

func (t *txWrapper) GetComment(commentID uint) (model.Comment, error) {
	var comment model.Comment
	err := t.tx.First(&comment, commentID).Error
	return comment, err
}

func (t *txWrapper) CreateComment(comment *model.Comment) error {
	return t.tx.Create(comment).Error
}

func (t *txWrapper) UpdatePostComments(postID uint, comments int) error {
	return t.tx.Model(&model.Post{}).Where("id = ?", postID).Update("comments", comments).Error
}

func (t *txWrapper) CreateNotification(n *model.Notification) error {
	return t.tx.Create(n).Error
}

func (t *txWrapper) DeleteLike(like *model.Like) error {
	return t.tx.Delete(like).Error
}

func (t *txWrapper) CreateLike(like *model.Like) error {
	return t.tx.Create(like).Error
}

func (t *txWrapper) UpdateCommentLikes(commentID uint, likes int) error {
	return t.tx.Model(&model.Comment{}).Where("id = ?", commentID).Update("likes", likes).Error
}

func (t *txWrapper) Commit() error   { return t.tx.Commit().Error }
func (t *txWrapper) Rollback() error { return t.tx.Rollback().Error }
