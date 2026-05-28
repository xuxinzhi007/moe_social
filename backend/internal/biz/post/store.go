package postbiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// ListPostsFilter 帖子列表查询条件。
type ListPostsFilter struct {
	Offset     int
	Limit      int
	ViewerUID  uint
	TopicTagID uint
	AuthorUID  uint
	FeedMode   string
}

// PostStore 帖子持久化（P4-D；默认由 internal/data/post 实现）。
type PostStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) PostStore

	GetUser(ctx context.Context, userID uint) (model.User, error)
	GetUsersByIDs(ctx context.Context, userIDs []uint) ([]model.User, error)
	GetUserSelect(ctx context.Context, userID uint, fields string) (model.User, error)

	GetPost(ctx context.Context, postID uint) (model.Post, error)
	GetPostWithTopicTags(ctx context.Context, postID uint) (model.Post, error)
	GetPostWithUserAndTopicTags(ctx context.Context, postID uint) (model.Post, error)
	SavePost(ctx context.Context, post *model.Post) error
	DeletePost(ctx context.Context, post *model.Post) error

	ListPosts(ctx context.Context, f ListPostsFilter) ([]model.Post, int64, error)

	PluckLikedTargetIDs(ctx context.Context, userID uint, targetType string, targetIDs []uint) ([]uint, error)
	FindLike(ctx context.Context, targetID, userID uint, targetType string) (model.Like, bool, error)
	CountLikesForPost(ctx context.Context, postID uint) (int64, error)
	CountCommentsForPost(ctx context.Context, postID uint) (int64, error)

	DeletePostTopics(ctx context.Context, postID uint) error
	FirstOrCreateTopicTag(ctx context.Context, name, color string) (model.TopicTag, error)
	CreatePostTopic(ctx context.Context, postID, topicTagID uint) error

	GetGroup(ctx context.Context, groupID uint64) (model.Group, error)
	GetGroupMember(ctx context.Context, groupID uint64, userID uint) (model.GroupMember, error)
	FindGroupPost(ctx context.Context, groupID uint64, postID uint) (model.GroupPost, bool, error)

	CreatePostReport(ctx context.Context, rep *model.PostReport) error

	Begin(ctx context.Context) (PostTx, error)
}

// PostTx 帖子事务。
type PostTx interface {
	CreatePost(post *model.Post) error
	FirstOrCreateTopicTag(name, color string) (model.TopicTag, error)
	DeletePostTopics(postID uint) error
	CreatePostTopic(postID, topicTagID uint) error

	GetGroup(groupID uint64) (model.Group, error)
	GetGroupMember(groupID uint64, userID uint) (model.GroupMember, error)
	FindGroupPost(groupID uint64, postID uint) (model.GroupPost, bool, error)
	CreateGroupPost(link *model.GroupPost) error

	DeleteLike(like *model.Like) error
	CreateLike(like *model.Like) error
	UpdatePostLikes(postID uint, likes int) error

	Commit() error
	Rollback() error
	DB() *gorm.DB
}
