package communitygw

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Community HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *communityapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *communityapp.AppService, legacy moe.SuperClient) *Gateway {
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

func (g *Gateway) GetGroups(ctx context.Context, in *moe.GetGroupsReq, opts ...grpc.CallOption) (*moe.GetGroupsResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroups(ctx, in)
	}
	return g.super.GetGroups(ctx, in, opts...)
}

func (g *Gateway) GetGroup(ctx context.Context, in *moe.GetGroupReq, opts ...grpc.CallOption) (*moe.GetGroupResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroup(ctx, in)
	}
	return g.super.GetGroup(ctx, in, opts...)
}

func (g *Gateway) GetUserGroups(ctx context.Context, in *moe.GetUserGroupsReq, opts ...grpc.CallOption) (*moe.GetUserGroupsResp, error) {
	if g.delegateLocal() {
		return g.local.GetUserGroups(ctx, in)
	}
	return g.super.GetUserGroups(ctx, in, opts...)
}

func (g *Gateway) GetGroupMembers(ctx context.Context, in *moe.GetGroupMembersReq, opts ...grpc.CallOption) (*moe.GetGroupMembersResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroupMembers(ctx, in)
	}
	return g.super.GetGroupMembers(ctx, in, opts...)
}

func (g *Gateway) GetGroupPosts(ctx context.Context, in *moe.GetGroupPostsReq, opts ...grpc.CallOption) (*moe.GetGroupPostsResp, error) {
	if g.delegateLocal() {
		return g.local.GetGroupPosts(ctx, in)
	}
	return g.super.GetGroupPosts(ctx, in, opts...)
}

func (g *Gateway) CreateGroup(ctx context.Context, in *moe.CreateGroupReq, opts ...grpc.CallOption) (*moe.CreateGroupResp, error) {
	if g.delegateLocal() {
		return g.local.CreateGroup(ctx, in)
	}
	return g.super.CreateGroup(ctx, in, opts...)
}

func (g *Gateway) JoinGroup(ctx context.Context, in *moe.JoinGroupReq, opts ...grpc.CallOption) (*moe.JoinGroupResp, error) {
	if g.delegateLocal() {
		return g.local.JoinGroup(ctx, in)
	}
	return g.super.JoinGroup(ctx, in, opts...)
}

func (g *Gateway) LeaveGroup(ctx context.Context, in *moe.LeaveGroupReq, opts ...grpc.CallOption) (*moe.LeaveGroupResp, error) {
	if g.delegateLocal() {
		return g.local.LeaveGroup(ctx, in)
	}
	return g.super.LeaveGroup(ctx, in, opts...)
}

func (g *Gateway) DeleteGroup(ctx context.Context, in *moe.DeleteGroupReq, opts ...grpc.CallOption) (*moe.DeleteGroupResp, error) {
	if g.delegateLocal() {
		return g.local.DeleteGroup(ctx, in)
	}
	return g.super.DeleteGroup(ctx, in, opts...)
}

func (g *Gateway) UpdateGroup(ctx context.Context, in *moe.UpdateGroupReq, opts ...grpc.CallOption) (*moe.UpdateGroupResp, error) {
	if g.delegateLocal() {
		return g.local.UpdateGroup(ctx, in)
	}
	return g.super.UpdateGroup(ctx, in, opts...)
}

func (g *Gateway) CreateGroupPost(ctx context.Context, in *moe.CreateGroupPostReq, opts ...grpc.CallOption) (*moe.CreateGroupPostResp, error) {
	if g.delegateLocal() {
		return g.local.CreateGroupPost(ctx, in)
	}
	return g.super.CreateGroupPost(ctx, in, opts...)
}
