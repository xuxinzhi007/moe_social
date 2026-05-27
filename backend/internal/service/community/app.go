// Package communityapp 社区/群组域应用服务。
package communityapp

import (
	"context"

	communitybiz "backend/internal/biz/community"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService 社区应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

func (s *AppService) GetGroups(ctx context.Context, in *super.GetGroupsReq) (*super.GetGroupsResp, error) {
	return communitybiz.ListGroups(ctx, s.db, in)
}

func (s *AppService) GetGroup(ctx context.Context, in *super.GetGroupReq) (*super.GetGroupResp, error) {
	return communitybiz.GetGroup(ctx, s.db, in)
}

func (s *AppService) GetUserGroups(ctx context.Context, in *super.GetUserGroupsReq) (*super.GetUserGroupsResp, error) {
	return communitybiz.ListUserGroups(ctx, s.db, in)
}

func (s *AppService) GetGroupMembers(ctx context.Context, in *super.GetGroupMembersReq) (*super.GetGroupMembersResp, error) {
	return communitybiz.ListGroupMembers(ctx, s.db, in)
}

func (s *AppService) GetGroupPosts(ctx context.Context, in *super.GetGroupPostsReq) (*super.GetGroupPostsResp, error) {
	return communitybiz.ListGroupPosts(ctx, s.db, in)
}

func (s *AppService) CreateGroup(ctx context.Context, in *super.CreateGroupReq) (*super.CreateGroupResp, error) {
	return communitybiz.CreateGroup(ctx, s.db, in)
}

func (s *AppService) JoinGroup(ctx context.Context, in *super.JoinGroupReq) (*super.JoinGroupResp, error) {
	return communitybiz.JoinGroup(ctx, s.db, in)
}

func (s *AppService) LeaveGroup(ctx context.Context, in *super.LeaveGroupReq) (*super.LeaveGroupResp, error) {
	return communitybiz.LeaveGroup(ctx, s.db, in)
}

func (s *AppService) DeleteGroup(ctx context.Context, in *super.DeleteGroupReq) (*super.DeleteGroupResp, error) {
	return communitybiz.DeleteGroup(ctx, s.db, in)
}

func (s *AppService) UpdateGroup(ctx context.Context, in *super.UpdateGroupReq) (*super.UpdateGroupResp, error) {
	return communitybiz.UpdateGroup(ctx, s.db, in)
}

func (s *AppService) CreateGroupPost(ctx context.Context, in *super.CreateGroupPostReq) (*super.CreateGroupPostResp, error) {
	return communitybiz.CreateGroupPost(ctx, s.db, in)
}
