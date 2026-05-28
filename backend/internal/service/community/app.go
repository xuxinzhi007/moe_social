// Package communityapp 社区/群组域应用服务。
package communityapp

import (
	"context"

	communitybiz "backend/internal/biz/community"
	postbiz "backend/internal/biz/post"
	communitydata "backend/internal/data/community"
	postdata "backend/internal/data/post"
	"backend/rpc/pb/moe"

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

func (s *AppService) GetGroups(ctx context.Context, in *moe.GetGroupsReq) (*moe.GetGroupsResp, error) {
	return communitybiz.ListGroups(ctx, s.store, in)
}

func (s *AppService) GetGroup(ctx context.Context, in *moe.GetGroupReq) (*moe.GetGroupResp, error) {
	return communitybiz.GetGroup(ctx, s.store, in)
}

func (s *AppService) GetUserGroups(ctx context.Context, in *moe.GetUserGroupsReq) (*moe.GetUserGroupsResp, error) {
	return communitybiz.ListUserGroups(ctx, s.store, in)
}

func (s *AppService) GetGroupMembers(ctx context.Context, in *moe.GetGroupMembersReq) (*moe.GetGroupMembersResp, error) {
	return communitybiz.ListGroupMembers(ctx, s.store, in)
}

func (s *AppService) GetGroupPosts(ctx context.Context, in *moe.GetGroupPostsReq) (*moe.GetGroupPostsResp, error) {
	return communitybiz.ListGroupPosts(ctx, s.store, s.postStore, in)
}

func (s *AppService) CreateGroup(ctx context.Context, in *moe.CreateGroupReq) (*moe.CreateGroupResp, error) {
	return communitybiz.CreateGroup(ctx, s.store, in)
}

func (s *AppService) JoinGroup(ctx context.Context, in *moe.JoinGroupReq) (*moe.JoinGroupResp, error) {
	return communitybiz.JoinGroup(ctx, s.store, in)
}

func (s *AppService) LeaveGroup(ctx context.Context, in *moe.LeaveGroupReq) (*moe.LeaveGroupResp, error) {
	return communitybiz.LeaveGroup(ctx, s.store, in)
}

func (s *AppService) DeleteGroup(ctx context.Context, in *moe.DeleteGroupReq) (*moe.DeleteGroupResp, error) {
	return communitybiz.DeleteGroup(ctx, s.store, in)
}

func (s *AppService) UpdateGroup(ctx context.Context, in *moe.UpdateGroupReq) (*moe.UpdateGroupResp, error) {
	return communitybiz.UpdateGroup(ctx, s.store, in)
}

func (s *AppService) CreateGroupPost(ctx context.Context, in *moe.CreateGroupPostReq) (*moe.CreateGroupPostResp, error) {
	return communitybiz.CreateGroupPost(ctx, s.store, s.postStore, in)
}
