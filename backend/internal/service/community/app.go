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
	out, err := communitybiz.ListGroups(ctx, s.store, communityv1.GetGroupsRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.GetGroupsReplyFromMoe(out), nil
}

func (s *AppService) GetGroup(ctx context.Context, in *communityv1.GetGroupRequest) (*communityv1.GetGroupReply, error) {
	out, err := communitybiz.GetGroup(ctx, s.store, communityv1.GetGroupRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.GetGroupReplyFromMoe(out), nil
}

func (s *AppService) GetUserGroups(ctx context.Context, in *communityv1.GetUserGroupsRequest) (*communityv1.GetUserGroupsReply, error) {
	out, err := communitybiz.ListUserGroups(ctx, s.store, communityv1.GetUserGroupsRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.GetUserGroupsReplyFromMoe(out), nil
}

func (s *AppService) GetGroupMembers(ctx context.Context, in *communityv1.GetGroupMembersRequest) (*communityv1.GetGroupMembersReply, error) {
	out, err := communitybiz.ListGroupMembers(ctx, s.store, communityv1.GetGroupMembersRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.GetGroupMembersReplyFromMoe(out), nil
}

func (s *AppService) GetGroupPosts(ctx context.Context, in *communityv1.GetGroupPostsRequest) (*communityv1.GetGroupPostsReply, error) {
	out, err := communitybiz.ListGroupPosts(ctx, s.store, s.postStore, communityv1.GetGroupPostsRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.GetGroupPostsReplyFromMoe(out), nil
}

func (s *AppService) CreateGroup(ctx context.Context, in *communityv1.CreateGroupRequest) (*communityv1.CreateGroupReply, error) {
	out, err := communitybiz.CreateGroup(ctx, s.store, communityv1.CreateGroupRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.CreateGroupReplyFromMoe(out), nil
}

func (s *AppService) JoinGroup(ctx context.Context, in *communityv1.JoinGroupRequest) (*communityv1.JoinGroupReply, error) {
	out, err := communitybiz.JoinGroup(ctx, s.store, communityv1.JoinGroupRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.JoinGroupReplyFromMoe(out), nil
}

func (s *AppService) LeaveGroup(ctx context.Context, in *communityv1.LeaveGroupRequest) (*communityv1.LeaveGroupReply, error) {
	out, err := communitybiz.LeaveGroup(ctx, s.store, communityv1.LeaveGroupRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.LeaveGroupReplyFromMoe(out), nil
}

func (s *AppService) DeleteGroup(ctx context.Context, in *communityv1.DeleteGroupRequest) (*communityv1.DeleteGroupReply, error) {
	out, err := communitybiz.DeleteGroup(ctx, s.store, communityv1.DeleteGroupRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.DeleteGroupReplyFromMoe(out), nil
}

func (s *AppService) UpdateGroup(ctx context.Context, in *communityv1.UpdateGroupRequest) (*communityv1.UpdateGroupReply, error) {
	out, err := communitybiz.UpdateGroup(ctx, s.store, communityv1.UpdateGroupRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.UpdateGroupReplyFromMoe(out), nil
}

func (s *AppService) CreateGroupPost(ctx context.Context, in *communityv1.CreateGroupPostRequest) (*communityv1.CreateGroupPostReply, error) {
	out, err := communitybiz.CreateGroupPost(ctx, s.store, s.postStore, communityv1.CreateGroupPostRequestToMoe(in))
	if err != nil {
		return nil, err
	}
	return communityv1.CreateGroupPostReplyFromMoe(out), nil
}
