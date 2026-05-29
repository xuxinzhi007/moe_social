// Package communityapp 社区/群组域应用服务。
package communityapp

import (
	"context"

	communityv1 "backend/api/community/v1"
	communitybiz "backend/internal/biz/community"
	postbiz "backend/internal/biz/post"
	communitydata "backend/internal/data/community"
	postdata "backend/internal/data/post"

	"gorm.io/gorm"
)

// AppService 社区应用层。
type AppService struct {
	store     communitybiz.CommunityStore
	postStore postbiz.PostStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		store:     communitydata.NewStore(db),
		postStore: postdata.NewStore(db),
	}
}

func (s *AppService) GetGroups(ctx context.Context, in *communityv1.GetGroupsRequest) (*communityv1.GetGroupsReply, error) {
	return communitybiz.ListGroups(ctx, s.store, in)
}

func (s *AppService) GetGroup(ctx context.Context, in *communityv1.GetGroupRequest) (*communityv1.GetGroupReply, error) {
	return communitybiz.GetGroup(ctx, s.store, in)
}

func (s *AppService) GetUserGroups(ctx context.Context, in *communityv1.GetUserGroupsRequest) (*communityv1.GetUserGroupsReply, error) {
	return communitybiz.ListUserGroups(ctx, s.store, in)
}

func (s *AppService) GetGroupMembers(ctx context.Context, in *communityv1.GetGroupMembersRequest) (*communityv1.GetGroupMembersReply, error) {
	return communitybiz.ListGroupMembers(ctx, s.store, in)
}

func (s *AppService) GetGroupPosts(ctx context.Context, in *communityv1.GetGroupPostsRequest) (*communityv1.GetGroupPostsReply, error) {
	return communitybiz.ListGroupPosts(ctx, s.store, s.postStore, in)
}

func (s *AppService) CreateGroup(ctx context.Context, in *communityv1.CreateGroupRequest) (*communityv1.CreateGroupReply, error) {
	return communitybiz.CreateGroup(ctx, s.store, in)
}

func (s *AppService) JoinGroup(ctx context.Context, in *communityv1.JoinGroupRequest) (*communityv1.JoinGroupReply, error) {
	return communitybiz.JoinGroup(ctx, s.store, in)
}

func (s *AppService) LeaveGroup(ctx context.Context, in *communityv1.LeaveGroupRequest) (*communityv1.LeaveGroupReply, error) {
	return communitybiz.LeaveGroup(ctx, s.store, in)
}

func (s *AppService) DeleteGroup(ctx context.Context, in *communityv1.DeleteGroupRequest) (*communityv1.DeleteGroupReply, error) {
	return communitybiz.DeleteGroup(ctx, s.store, in)
}

func (s *AppService) UpdateGroup(ctx context.Context, in *communityv1.UpdateGroupRequest) (*communityv1.UpdateGroupReply, error) {
	return communitybiz.UpdateGroup(ctx, s.store, in)
}

func (s *AppService) CreateGroupPost(ctx context.Context, in *communityv1.CreateGroupPostRequest) (*communityv1.CreateGroupPostReply, error) {
	return communitybiz.CreateGroupPost(ctx, s.store, s.postStore, in)
}
