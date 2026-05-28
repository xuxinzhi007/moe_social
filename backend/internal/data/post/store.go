package postdata

import (
	"context"
	"errors"

	postbiz "backend/internal/biz/post"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.PostStore（P4-D）。
func NewStore(db *gorm.DB) postbiz.PostStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) postbiz.PostStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) GetUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("id = ?", userID).First(&user).Error
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

func (s *store) GetUserSelect(ctx context.Context, userID uint, fields string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Select(fields).First(&user, userID).Error
	return user, err
}

func (s *store) GetPost(ctx context.Context, postID uint) (model.Post, error) {
	var post model.Post
	err := s.db.WithContext(ctx).First(&post, postID).Error
	return post, err
}

func (s *store) GetPostWithTopicTags(ctx context.Context, postID uint) (model.Post, error) {
	var post model.Post
	err := s.db.WithContext(ctx).Preload("TopicTags").Where("id = ?", postID).First(&post).Error
	return post, err
}

func (s *store) GetPostWithUserAndTopicTags(ctx context.Context, postID uint) (model.Post, error) {
	var post model.Post
	err := s.db.WithContext(ctx).Preload("User").Preload("TopicTags").First(&post, postID).Error
	return post, err
}

func (s *store) SavePost(ctx context.Context, post *model.Post) error {
	return s.db.WithContext(ctx).Save(post).Error
}

func (s *store) DeletePost(ctx context.Context, post *model.Post) error {
	return s.db.WithContext(ctx).Delete(post).Error
}

func moderationVisibleScope(viewerUserID uint) func(db *gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		return db.Where("(moderation_status IS NULL OR moderation_status <> ?)", "rejected").
			Where("(moderation_status IS NULL OR moderation_status = '' OR moderation_status = 'ok') OR (moderation_status = 'pending' AND user_id = ?)", viewerUserID)
	}
}

func (s *store) ListPosts(ctx context.Context, f postbiz.ListPostsFilter) ([]model.Post, int64, error) {
	listQuery := s.db.WithContext(ctx).Model(&model.Post{}).Scopes(moderationVisibleScope(f.ViewerUID))
	if f.TopicTagID > 0 {
		sub := s.db.Model(&model.PostTopic{}).Select("post_id").Where("topic_tag_id = ?", f.TopicTagID)
		listQuery = listQuery.Where("id IN (?)", sub)
	}
	if f.AuthorUID > 0 {
		listQuery = listQuery.Where("user_id = ?", f.AuthorUID)
	} else if f.FeedMode == "following" {
		if f.ViewerUID == 0 {
			listQuery = listQuery.Where("1 = 0")
		} else {
			sub := s.db.Model(&model.Follow{}).Select("following_id").Where("follower_id = ?", f.ViewerUID)
			listQuery = listQuery.Where("user_id = ? OR user_id IN (?)", f.ViewerUID, sub)
		}
	}
	switch f.FeedMode {
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
	err := listQuery.Preload("TopicTags").Offset(f.Offset).Limit(f.Limit).Find(&posts).Error
	return posts, total, err
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

func (s *store) CountLikesForPost(ctx context.Context, postID uint) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.Like{}).
		Where("target_type = 'post' AND target_id = ?", postID).Count(&count).Error
	return count, err
}

func (s *store) CountCommentsForPost(ctx context.Context, postID uint) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.Comment{}).
		Where("post_id = ? AND deleted_at IS NULL", postID).Count(&count).Error
	return count, err
}

func (s *store) DeletePostTopics(ctx context.Context, postID uint) error {
	return s.db.WithContext(ctx).Where("post_id = ?", postID).Delete(&model.PostTopic{}).Error
}

func (s *store) FirstOrCreateTopicTag(ctx context.Context, name, color string) (model.TopicTag, error) {
	var tag model.TopicTag
	err := s.db.WithContext(ctx).Where("name = ?", name).FirstOrCreate(&tag, model.TopicTag{
		Name: name, Color: color,
	}).Error
	return tag, err
}

func (s *store) CreatePostTopic(ctx context.Context, postID, topicTagID uint) error {
	return s.db.WithContext(ctx).Create(&model.PostTopic{PostID: postID, TopicTagID: topicTagID}).Error
}

func (s *store) GetGroup(ctx context.Context, groupID uint64) (model.Group, error) {
	var group model.Group
	err := s.db.WithContext(ctx).First(&group, groupID).Error
	return group, err
}

func (s *store) GetGroupMember(ctx context.Context, groupID uint64, userID uint) (model.GroupMember, error) {
	var member model.GroupMember
	err := s.db.WithContext(ctx).Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error
	return member, err
}

func (s *store) FindGroupPost(ctx context.Context, groupID uint64, postID uint) (model.GroupPost, bool, error) {
	var link model.GroupPost
	err := s.db.WithContext(ctx).Where("group_id = ? AND post_id = ?", groupID, postID).First(&link).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GroupPost{}, false, nil
	}
	return link, err == nil, err
}

func (s *store) CreatePostReport(ctx context.Context, rep *model.PostReport) error {
	return s.db.WithContext(ctx).Create(rep).Error
}

func (s *store) Begin(ctx context.Context) (postbiz.PostTx, error) {
	tx := s.db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}
	return &txWrapper{tx: tx}, nil
}

type txWrapper struct {
	tx *gorm.DB
}

func (t *txWrapper) CreatePost(post *model.Post) error {
	return t.tx.Create(post).Error
}

func (t *txWrapper) FirstOrCreateTopicTag(name, color string) (model.TopicTag, error) {
	var tag model.TopicTag
	err := t.tx.Where("name = ?", name).FirstOrCreate(&tag, model.TopicTag{Name: name, Color: color}).Error
	return tag, err
}

func (t *txWrapper) DeletePostTopics(postID uint) error {
	return t.tx.Where("post_id = ?", postID).Delete(&model.PostTopic{}).Error
}

func (t *txWrapper) CreatePostTopic(postID, topicTagID uint) error {
	return t.tx.Create(&model.PostTopic{PostID: postID, TopicTagID: topicTagID}).Error
}

func (t *txWrapper) GetGroup(groupID uint64) (model.Group, error) {
	var group model.Group
	err := t.tx.First(&group, groupID).Error
	return group, err
}

func (t *txWrapper) GetGroupMember(groupID uint64, userID uint) (model.GroupMember, error) {
	var member model.GroupMember
	err := t.tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error
	return member, err
}

func (t *txWrapper) FindGroupPost(groupID uint64, postID uint) (model.GroupPost, bool, error) {
	var link model.GroupPost
	err := t.tx.Where("group_id = ? AND post_id = ?", groupID, postID).First(&link).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GroupPost{}, false, nil
	}
	return link, err == nil, err
}

func (t *txWrapper) CreateGroupPost(link *model.GroupPost) error {
	return t.tx.Create(link).Error
}

func (t *txWrapper) DeleteLike(like *model.Like) error {
	return t.tx.Delete(like).Error
}

func (t *txWrapper) CreateLike(like *model.Like) error {
	return t.tx.Create(like).Error
}

func (t *txWrapper) UpdatePostLikes(postID uint, likes int) error {
	return t.tx.Model(&model.Post{}).Where("id = ?", postID).Update("likes", likes).Error
}

func (t *txWrapper) Commit() error   { return t.tx.Commit().Error }
func (t *txWrapper) Rollback() error { return t.tx.Rollback().Error }
func (t *txWrapper) DB() *gorm.DB    { return t.tx }
