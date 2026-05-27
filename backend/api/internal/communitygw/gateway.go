package communitygw

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway Community HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *communityapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *communityapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) delegateLocal() bool {
	return g != nil && g.local != nil
}

func (g *Gateway) GetGroups(ctx context.Context, in *super.GetGroupsReq, opts ...grpc.CallOption) (*super.GetGroupsResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroups(ctx, in)
	}
	return g.super.GetGroups(ctx, in, opts...)
}

func (g *Gateway) GetGroup(ctx context.Context, in *super.GetGroupReq, opts ...grpc.CallOption) (*super.GetGroupResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroup(ctx, in)
	}
	return g.super.GetGroup(ctx, in, opts...)
}

func (g *Gateway) GetUserGroups(ctx context.Context, in *super.GetUserGroupsReq, opts ...grpc.CallOption) (*super.GetUserGroupsResp, error) {
	if g.delegateLocal() {
		return g.local.GetUserGroups(ctx, in)
	}
	return g.super.GetUserGroups(ctx, in, opts...)
}

func (g *Gateway) GetGroupMembers(ctx context.Context, in *super.GetGroupMembersReq, opts ...grpc.CallOption) (*super.GetGroupMembersResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroupMembers(ctx, in)
	}
	return g.super.GetGroupMembers(ctx, in, opts...)
}

func (g *Gateway) GetGroupPosts(ctx context.Context, in *super.GetGroupPostsReq, opts ...grpc.CallOption) (*super.GetGroupPostsResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroupPosts(ctx, in)
	}
	return g.super.GetGroupPosts(ctx, in, opts...)
}

func (g *Gateway) CreateGroup(ctx context.Context, in *super.CreateGroupReq, opts ...grpc.CallOption) (*super.CreateGroupResp, error) {
	if g.delegateLocal() {
		return g.local.CreateGroup(ctx, in)
	}
	return g.super.CreateGroup(ctx, in, opts...)
}

func (g *Gateway) JoinGroup(ctx context.Context, in *super.JoinGroupReq, opts ...grpc.CallOption) (*super.JoinGroupResp, error) {
	if g.delegateLocal() {
		return g.local.JoinGroup(ctx, in)
	}
	return g.super.JoinGroup(ctx, in, opts...)
}

func (g *Gateway) LeaveGroup(ctx context.Context, in *super.LeaveGroupReq, opts ...grpc.CallOption) (*super.LeaveGroupResp, error) {
	if g.delegateLocal() {
		return g.local.LeaveGroup(ctx, in)
	}
	return g.super.LeaveGroup(ctx, in, opts...)
}

func (g *Gateway) DeleteGroup(ctx context.Context, in *super.DeleteGroupReq, opts ...grpc.CallOption) (*super.DeleteGroupResp, error) {
	if g.delegateLocal() {
		return g.local.DeleteGroup(ctx, in)
	}
	return g.super.DeleteGroup(ctx, in, opts...)
}

func (g *Gateway) UpdateGroup(ctx context.Context, in *super.UpdateGroupReq, opts ...grpc.CallOption) (*super.UpdateGroupResp, error) {
	if g.delegateLocal() {
		return g.local.UpdateGroup(ctx, in)
	}
	return g.super.UpdateGroup(ctx, in, opts...)
}

func (g *Gateway) CreateGroupPost(ctx context.Context, in *super.CreateGroupPostReq, opts ...grpc.CallOption) (*super.CreateGroupPostResp, error) {
	if g.delegateLocal() {
		return g.local.CreateGroupPost(ctx, in)
	}
	return g.super.CreateGroupPost(ctx, in, opts...)
}
