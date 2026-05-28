package communitybiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// CommunityStore 社区/群组持久化（P4-D；默认由 internal/data/community 实现）。
type CommunityStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) CommunityStore

	ListActiveGroups(ctx context.Context, keyword string, isPublic bool, offset, limit int) ([]model.Group, int64, error)
	GetGroupByID(ctx context.Context, id uint) (model.Group, error)
	CountUserMemberships(ctx context.Context, userID uint) (int64, error)
	ListUserMemberships(ctx context.Context, userID uint, offset, limit int) ([]model.GroupMember, error)
	FindGroupsByIDs(ctx context.Context, ids []uint) ([]model.Group, error)
	CountGroupMembers(ctx context.Context, groupID uint) (int64, error)
	ListGroupMembers(ctx context.Context, groupID uint, offset, limit int) ([]model.GroupMember, error)
	CountGroupPostLinks(ctx context.Context, groupID uint) (int64, error)
	ListGroupPostLinks(ctx context.Context, groupID uint, offset, limit int) ([]model.GroupPost, error)
	GetUser(ctx context.Context, userID uint) (model.User, error)
	FindUsersByIDs(ctx context.Context, ids []uint) ([]model.User, error)
	FindGroupMember(ctx context.Context, groupID, userID uint) (model.GroupMember, error)
	FindGroupMemberOptional(ctx context.Context, groupID, userID uint) (model.GroupMember, bool, error)
	GetPostWithTags(ctx context.Context, postID uint) (model.Post, error)
	FindGroupPostLink(ctx context.Context, groupID, postID uint) (model.GroupPost, bool, error)
	CreateGroupPostLink(ctx context.Context, link *model.GroupPost) error
	FindVisiblePostsByIDs(ctx context.Context, postIDs []uint, viewerUID uint) ([]model.Post, error)
	UpdateGroupFields(ctx context.Context, groupID uint, updates map[string]interface{}) error

	Begin(ctx context.Context) (CommunityTx, error)
}

// CommunityTx 群组写操作事务。
type CommunityTx interface {
	CreateGroup(group *model.Group) error
	CreateGroupMember(member *model.GroupMember) error
	GetGroup(id uint) (model.Group, error)
	FindGroupMemberOptional(groupID, userID uint) (model.GroupMember, bool, error)
	UpdateGroupMemberCount(group *model.Group, count int) error
	DeleteGroupMember(member *model.GroupMember) error
	DeleteGroupMembersByGroupID(groupID uint) error
	DeleteGroup(group *model.Group) error
	Commit() error
	Rollback() error
}
