package communitydata

import (
	"context"
	"errors"

	communitybiz "backend/internal/biz/community"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.CommunityStore（P4-D）。
func NewStore(db *gorm.DB) communitybiz.CommunityStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) communitybiz.CommunityStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) ListActiveGroups(ctx context.Context, keyword string, isPublic bool, offset, limit int) ([]model.Group, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.Group{}).Where("status = ?", "active")
	if isPublic {
		q = q.Where("is_public = ?", true)
	}
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("name LIKE ? OR description LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var groups []model.Group
	err := q.Offset(offset).Limit(limit).Find(&groups).Error
	return groups, total, err
}

func (s *store) GetGroupByID(ctx context.Context, id uint) (model.Group, error) {
	var group model.Group
	err := s.db.WithContext(ctx).First(&group, id).Error
	return group, err
}

func (s *store) CountUserMemberships(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.GroupMember{}).Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *store) ListUserMemberships(ctx context.Context, userID uint, offset, limit int) ([]model.GroupMember, error) {
	var members []model.GroupMember
	err := s.db.WithContext(ctx).Model(&model.GroupMember{}).
		Where("user_id = ?", userID).Offset(offset).Limit(limit).Find(&members).Error
	return members, err
}

func (s *store) FindGroupsByIDs(ctx context.Context, ids []uint) ([]model.Group, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var groups []model.Group
	err := s.db.WithContext(ctx).Where("id IN ?", ids).Find(&groups).Error
	return groups, err
}

func (s *store) CountGroupMembers(ctx context.Context, groupID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.GroupMember{}).Where("group_id = ?", groupID).Count(&total).Error
	return total, err
}

func (s *store) ListGroupMembers(ctx context.Context, groupID uint, offset, limit int) ([]model.GroupMember, error) {
	var members []model.GroupMember
	err := s.db.WithContext(ctx).Model(&model.GroupMember{}).
		Where("group_id = ?", groupID).Offset(offset).Limit(limit).Find(&members).Error
	return members, err
}

func (s *store) CountGroupPostLinks(ctx context.Context, groupID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.GroupPost{}).Where("group_id = ?", groupID).Count(&total).Error
	return total, err
}

func (s *store) ListGroupPostLinks(ctx context.Context, groupID uint, offset, limit int) ([]model.GroupPost, error) {
	var links []model.GroupPost
	err := s.db.WithContext(ctx).Model(&model.GroupPost{}).
		Where("group_id = ?", groupID).Order("created_at DESC").
		Offset(offset).Limit(limit).Find(&links).Error
	return links, err
}

func (s *store) GetUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *store) FindUsersByIDs(ctx context.Context, ids []uint) ([]model.User, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var users []model.User
	err := s.db.WithContext(ctx).Where("id IN ?", ids).Find(&users).Error
	return users, err
}

func (s *store) FindGroupMember(ctx context.Context, groupID, userID uint) (model.GroupMember, error) {
	var member model.GroupMember
	err := s.db.WithContext(ctx).Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error
	return member, err
}

func (s *store) FindGroupMemberOptional(ctx context.Context, groupID, userID uint) (model.GroupMember, bool, error) {
	var member model.GroupMember
	err := s.db.WithContext(ctx).Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GroupMember{}, false, nil
	}
	return member, err == nil, err
}

func (s *store) GetPostWithTags(ctx context.Context, postID uint) (model.Post, error) {
	var post model.Post
	err := s.db.WithContext(ctx).Preload("TopicTags").First(&post, postID).Error
	return post, err
}

func (s *store) FindGroupPostLink(ctx context.Context, groupID, postID uint) (model.GroupPost, bool, error) {
	var link model.GroupPost
	err := s.db.WithContext(ctx).Where("group_id = ? AND post_id = ?", groupID, postID).First(&link).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GroupPost{}, false, nil
	}
	return link, err == nil, err
}

func (s *store) CreateGroupPostLink(ctx context.Context, link *model.GroupPost) error {
	return s.db.WithContext(ctx).Create(link).Error
}

func moderationVisibleScope(viewerUserID uint) func(db *gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		return db.Where("(moderation_status IS NULL OR moderation_status <> ?)", "rejected").
			Where("(moderation_status IS NULL OR moderation_status = '' OR moderation_status = 'ok') OR (moderation_status = 'pending' AND user_id = ?)", viewerUserID)
	}
}

func (s *store) FindVisiblePostsByIDs(ctx context.Context, postIDs []uint, viewerUID uint) ([]model.Post, error) {
	if len(postIDs) == 0 {
		return nil, nil
	}
	var posts []model.Post
	err := s.db.WithContext(ctx).Preload("TopicTags").
		Model(&model.Post{}).
		Scopes(moderationVisibleScope(viewerUID)).
		Where("id IN ?", postIDs).
		Find(&posts).Error
	return posts, err
}

func (s *store) UpdateGroupFields(ctx context.Context, groupID uint, updates map[string]interface{}) error {
	return s.db.WithContext(ctx).Model(&model.Group{}).Where("id = ?", groupID).Updates(updates).Error
}

func (s *store) Begin(ctx context.Context) (communitybiz.CommunityTx, error) {
	tx := s.db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}
	return &txWrapper{tx: tx}, nil
}

type txWrapper struct {
	tx *gorm.DB
}

func (t *txWrapper) CreateGroup(group *model.Group) error {
	return t.tx.Create(group).Error
}

func (t *txWrapper) CreateGroupMember(member *model.GroupMember) error {
	return t.tx.Create(member).Error
}

func (t *txWrapper) GetGroup(id uint) (model.Group, error) {
	var group model.Group
	err := t.tx.First(&group, id).Error
	return group, err
}

func (t *txWrapper) FindGroupMemberOptional(groupID, userID uint) (model.GroupMember, bool, error) {
	var member model.GroupMember
	err := t.tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.GroupMember{}, false, nil
	}
	return member, err == nil, err
}

func (t *txWrapper) UpdateGroupMemberCount(group *model.Group, count int) error {
	return t.tx.Model(group).Update("member_count", count).Error
}

func (t *txWrapper) DeleteGroupMember(member *model.GroupMember) error {
	return t.tx.Delete(member).Error
}

func (t *txWrapper) DeleteGroupMembersByGroupID(groupID uint) error {
	return t.tx.Where("group_id = ?", groupID).Delete(&model.GroupMember{}).Error
}

func (t *txWrapper) DeleteGroup(group *model.Group) error {
	return t.tx.Delete(group).Error
}

func (t *txWrapper) Commit() error   { return t.tx.Commit().Error }
func (t *txWrapper) Rollback() error { return t.tx.Rollback().Error }
