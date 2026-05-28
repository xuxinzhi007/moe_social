package communitygw

import (
	"backend/api/internal/gwutil"
	"context"

	communityv1 "backend/api/community/v1"
	communityapp "backend/internal/service/community"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Community HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *communityapp.AppService
}

// New 构造网关。
func New(local *communityapp.AppService) *Gateway {
	return &Gateway{local: local}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) delegateLocal() bool {
	return g != nil && g.local != nil
}

func (g *Gateway) GetGroups(ctx context.Context, in *moe.GetGroupsReq, opts ...grpc.CallOption) (*moe.GetGroupsResp, error) {
	if g.delegateLocal() {
		out, err := g.local.GetGroups(ctx, communityv1.GetGroupsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.GetGroupsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGroup(ctx context.Context, in *moe.GetGroupReq, opts ...grpc.CallOption) (*moe.GetGroupResp, error) {
	if g.delegateLocal() {
		out, err := g.local.GetGroup(ctx, communityv1.GetGroupRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.GetGroupReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserGroups(ctx context.Context, in *moe.GetUserGroupsReq, opts ...grpc.CallOption) (*moe.GetUserGroupsResp, error) {
	if g.delegateLocal() {
		out, err := g.local.GetUserGroups(ctx, communityv1.GetUserGroupsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.GetUserGroupsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGroupMembers(ctx context.Context, in *moe.GetGroupMembersReq, opts ...grpc.CallOption) (*moe.GetGroupMembersResp, error) {
	if g.delegateLocal() {
		out, err := g.local.GetGroupMembers(ctx, communityv1.GetGroupMembersRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.GetGroupMembersReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetGroupPosts(ctx context.Context, in *moe.GetGroupPostsReq, opts ...grpc.CallOption) (*moe.GetGroupPostsResp, error) {
	if g.delegateLocal() {
		out, err := g.local.GetGroupPosts(ctx, communityv1.GetGroupPostsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.GetGroupPostsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateGroup(ctx context.Context, in *moe.CreateGroupReq, opts ...grpc.CallOption) (*moe.CreateGroupResp, error) {
	if g.delegateLocal() {
		out, err := g.local.CreateGroup(ctx, communityv1.CreateGroupRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.CreateGroupReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) JoinGroup(ctx context.Context, in *moe.JoinGroupReq, opts ...grpc.CallOption) (*moe.JoinGroupResp, error) {
	if g.delegateLocal() {
		out, err := g.local.JoinGroup(ctx, communityv1.JoinGroupRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.JoinGroupReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) LeaveGroup(ctx context.Context, in *moe.LeaveGroupReq, opts ...grpc.CallOption) (*moe.LeaveGroupResp, error) {
	if g.delegateLocal() {
		out, err := g.local.LeaveGroup(ctx, communityv1.LeaveGroupRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.LeaveGroupReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteGroup(ctx context.Context, in *moe.DeleteGroupReq, opts ...grpc.CallOption) (*moe.DeleteGroupResp, error) {
	if g.delegateLocal() {
		out, err := g.local.DeleteGroup(ctx, communityv1.DeleteGroupRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.DeleteGroupReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateGroup(ctx context.Context, in *moe.UpdateGroupReq, opts ...grpc.CallOption) (*moe.UpdateGroupResp, error) {
	if g.delegateLocal() {
		out, err := g.local.UpdateGroup(ctx, communityv1.UpdateGroupRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.UpdateGroupReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateGroupPost(ctx context.Context, in *moe.CreateGroupPostReq, opts ...grpc.CallOption) (*moe.CreateGroupPostResp, error) {
	if g.delegateLocal() {
		out, err := g.local.CreateGroupPost(ctx, communityv1.CreateGroupPostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return communityv1.CreateGroupPostReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
