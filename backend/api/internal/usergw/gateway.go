package usergw

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway User HTTP→biz 或 super RPC 回退。
type Gateway struct {
	local *userapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *userapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由。
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

func (g *Gateway) Login(ctx context.Context, in *super.LoginReq, opts ...grpc.CallOption) (*super.LoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.Login(ctx, in)
	}
	return g.super.Login(ctx, in, opts...)
}

func (g *Gateway) Register(ctx context.Context, in *super.RegisterReq, opts ...grpc.CallOption) (*super.RegisterResp, error) {
	if g != nil && g.local != nil {
		return g.local.Register(ctx, in)
	}
	return g.super.Register(ctx, in, opts...)
}

func (g *Gateway) GetUserInfo(ctx context.Context, in *super.GetUserInfoReq, opts ...grpc.CallOption) (*super.GetUserInfoResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserInfo(ctx, in)
	}
	return g.super.GetUserInfo(ctx, in, opts...)
}

func (g *Gateway) GetUser(ctx context.Context, in *super.GetUserReq, opts ...grpc.CallOption) (*super.GetUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUser(ctx, in)
	}
	return g.super.GetUser(ctx, in, opts...)
}

func (g *Gateway) GetUserVipStatus(ctx context.Context, in *super.GetUserVipStatusReq, opts ...grpc.CallOption) (*super.GetUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserVipStatus(ctx, in)
	}
	return g.super.GetUserVipStatus(ctx, in, opts...)
}

func (g *Gateway) CheckUserVip(ctx context.Context, in *super.CheckUserVipReq, opts ...grpc.CallOption) (*super.CheckUserVipResp, error) {
	if g != nil && g.local != nil {
		return g.local.CheckUserVip(ctx, in)
	}
	return g.super.CheckUserVip(ctx, in, opts...)
}

func (g *Gateway) FollowUser(ctx context.Context, in *super.FollowUserReq, opts ...grpc.CallOption) (*super.FollowUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.Follow(ctx, in)
	}
	return g.super.FollowUser(ctx, in, opts...)
}

func (g *Gateway) UnfollowUser(ctx context.Context, in *super.UnfollowUserReq, opts ...grpc.CallOption) (*super.FollowUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.Unfollow(ctx, in)
	}
	return g.super.UnfollowUser(ctx, in, opts...)
}

func (g *Gateway) CheckFollow(ctx context.Context, in *super.CheckFollowReq, opts ...grpc.CallOption) (*super.CheckFollowResp, error) {
	if g != nil && g.local != nil {
		return g.local.CheckFollow(ctx, in)
	}
	return g.super.CheckFollow(ctx, in, opts...)
}

func (g *Gateway) GetFollowers(ctx context.Context, in *super.GetFollowersReq, opts ...grpc.CallOption) (*super.GetFollowersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetFollowers(ctx, in)
	}
	return g.super.GetFollowers(ctx, in, opts...)
}

func (g *Gateway) GetFollowings(ctx context.Context, in *super.GetFollowingsReq, opts ...grpc.CallOption) (*super.GetFollowingsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetFollowings(ctx, in)
	}
	return g.super.GetFollowings(ctx, in, opts...)
}

func (g *Gateway) SendFriendRequest(ctx context.Context, in *super.SendFriendRequestReq, opts ...grpc.CallOption) (*super.SendFriendRequestResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendFriendRequest(ctx, in)
	}
	return g.super.SendFriendRequest(ctx, in, opts...)
}

func (g *Gateway) ListIncomingFriendRequests(ctx context.Context, in *super.ListIncomingFriendRequestsReq, opts ...grpc.CallOption) (*super.ListIncomingFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListIncomingFriendRequests(ctx, in)
	}
	return g.super.ListIncomingFriendRequests(ctx, in, opts...)
}

func (g *Gateway) ListOutgoingFriendRequests(ctx context.Context, in *super.ListOutgoingFriendRequestsReq, opts ...grpc.CallOption) (*super.ListOutgoingFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListOutgoingFriendRequests(ctx, in)
	}
	return g.super.ListOutgoingFriendRequests(ctx, in, opts...)
}

func (g *Gateway) AcceptFriendRequest(ctx context.Context, in *super.AcceptFriendRequestReq, opts ...grpc.CallOption) (*super.AcceptFriendRequestResp, error) {
	if g != nil && g.local != nil {
		return g.local.AcceptFriendRequest(ctx, in)
	}
	return g.super.AcceptFriendRequest(ctx, in, opts...)
}

func (g *Gateway) RejectFriendRequest(ctx context.Context, in *super.RejectFriendRequestReq, opts ...grpc.CallOption) (*super.RejectFriendRequestResp, error) {
	if g != nil && g.local != nil {
		return g.local.RejectFriendRequest(ctx, in)
	}
	return g.super.RejectFriendRequest(ctx, in, opts...)
}

func (g *Gateway) ListFriends(ctx context.Context, in *super.ListFriendsReq, opts ...grpc.CallOption) (*super.ListFriendsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListFriends(ctx, in)
	}
	return g.super.ListFriends(ctx, in, opts...)
}

func (g *Gateway) GetFriendRelation(ctx context.Context, in *super.GetFriendRelationReq, opts ...grpc.CallOption) (*super.GetFriendRelationResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetFriendRelation(ctx, in)
	}
	return g.super.GetFriendRelation(ctx, in, opts...)
}

// Super 未迁移方法仍走 RPC。
func (g *Gateway) Super() super.SuperClient {
	if g == nil {
		return nil
	}
	return g.super
}
