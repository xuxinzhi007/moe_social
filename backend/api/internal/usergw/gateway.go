package usergw

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway User HTTP→biz 或 super RPC 回退。
type Gateway struct {
	local *userapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *userapp.AppService, legacy moe.SuperClient) *Gateway {
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

func (g *Gateway) Login(ctx context.Context, in *moe.LoginReq, opts ...grpc.CallOption) (*moe.LoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.Login(ctx, in)
	}
	return g.super.Login(ctx, in, opts...)
}

func (g *Gateway) Register(ctx context.Context, in *moe.RegisterReq, opts ...grpc.CallOption) (*moe.RegisterResp, error) {
	if g != nil && g.local != nil {
		return g.local.Register(ctx, in)
	}
	return g.super.Register(ctx, in, opts...)
}

func (g *Gateway) GetUserInfo(ctx context.Context, in *moe.GetUserInfoReq, opts ...grpc.CallOption) (*moe.GetUserInfoResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserInfo(ctx, in)
	}
	return g.super.GetUserInfo(ctx, in, opts...)
}

func (g *Gateway) GetUser(ctx context.Context, in *moe.GetUserReq, opts ...grpc.CallOption) (*moe.GetUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUser(ctx, in)
	}
	return g.super.GetUser(ctx, in, opts...)
}

func (g *Gateway) GetUserVipStatus(ctx context.Context, in *moe.GetUserVipStatusReq, opts ...grpc.CallOption) (*moe.GetUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserVipStatus(ctx, in)
	}
	return g.super.GetUserVipStatus(ctx, in, opts...)
}

func (g *Gateway) GetVipOrders(ctx context.Context, in *moe.GetVipOrdersReq, opts ...grpc.CallOption) (*moe.GetVipOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetVipOrders(ctx, in)
	}
	return g.super.GetVipOrders(ctx, in, opts...)
}

func (g *Gateway) CheckUserVip(ctx context.Context, in *moe.CheckUserVipReq, opts ...grpc.CallOption) (*moe.CheckUserVipResp, error) {
	if g != nil && g.local != nil {
		return g.local.CheckUserVip(ctx, in)
	}
	return g.super.CheckUserVip(ctx, in, opts...)
}

func (g *Gateway) FollowUser(ctx context.Context, in *moe.FollowUserReq, opts ...grpc.CallOption) (*moe.FollowUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.Follow(ctx, in)
	}
	return g.super.FollowUser(ctx, in, opts...)
}

func (g *Gateway) UnfollowUser(ctx context.Context, in *moe.UnfollowUserReq, opts ...grpc.CallOption) (*moe.FollowUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.Unfollow(ctx, in)
	}
	return g.super.UnfollowUser(ctx, in, opts...)
}

func (g *Gateway) CheckFollow(ctx context.Context, in *moe.CheckFollowReq, opts ...grpc.CallOption) (*moe.CheckFollowResp, error) {
	if g != nil && g.local != nil {
		return g.local.CheckFollow(ctx, in)
	}
	return g.super.CheckFollow(ctx, in, opts...)
}

func (g *Gateway) GetFollowers(ctx context.Context, in *moe.GetFollowersReq, opts ...grpc.CallOption) (*moe.GetFollowersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetFollowers(ctx, in)
	}
	return g.super.GetFollowers(ctx, in, opts...)
}

func (g *Gateway) GetFollowings(ctx context.Context, in *moe.GetFollowingsReq, opts ...grpc.CallOption) (*moe.GetFollowingsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetFollowings(ctx, in)
	}
	return g.super.GetFollowings(ctx, in, opts...)
}

func (g *Gateway) SendFriendRequest(ctx context.Context, in *moe.SendFriendRequestReq, opts ...grpc.CallOption) (*moe.SendFriendRequestResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendFriendRequest(ctx, in)
	}
	return g.super.SendFriendRequest(ctx, in, opts...)
}

func (g *Gateway) ListIncomingFriendRequests(ctx context.Context, in *moe.ListIncomingFriendRequestsReq, opts ...grpc.CallOption) (*moe.ListIncomingFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListIncomingFriendRequests(ctx, in)
	}
	return g.super.ListIncomingFriendRequests(ctx, in, opts...)
}

func (g *Gateway) ListOutgoingFriendRequests(ctx context.Context, in *moe.ListOutgoingFriendRequestsReq, opts ...grpc.CallOption) (*moe.ListOutgoingFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListOutgoingFriendRequests(ctx, in)
	}
	return g.super.ListOutgoingFriendRequests(ctx, in, opts...)
}

func (g *Gateway) AcceptFriendRequest(ctx context.Context, in *moe.AcceptFriendRequestReq, opts ...grpc.CallOption) (*moe.AcceptFriendRequestResp, error) {
	if g != nil && g.local != nil {
		return g.local.AcceptFriendRequest(ctx, in)
	}
	return g.super.AcceptFriendRequest(ctx, in, opts...)
}

func (g *Gateway) RejectFriendRequest(ctx context.Context, in *moe.RejectFriendRequestReq, opts ...grpc.CallOption) (*moe.RejectFriendRequestResp, error) {
	if g != nil && g.local != nil {
		return g.local.RejectFriendRequest(ctx, in)
	}
	return g.super.RejectFriendRequest(ctx, in, opts...)
}

func (g *Gateway) ListFriends(ctx context.Context, in *moe.ListFriendsReq, opts ...grpc.CallOption) (*moe.ListFriendsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListFriends(ctx, in)
	}
	return g.super.ListFriends(ctx, in, opts...)
}

func (g *Gateway) GetFriendRelation(ctx context.Context, in *moe.GetFriendRelationReq, opts ...grpc.CallOption) (*moe.GetFriendRelationResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetFriendRelation(ctx, in)
	}
	return g.super.GetFriendRelation(ctx, in, opts...)
}

func (g *Gateway) GetNotifications(ctx context.Context, in *moe.GetNotificationsReq, opts ...grpc.CallOption) (*moe.GetNotificationsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetNotifications(ctx, in)
	}
	return g.super.GetNotifications(ctx, in, opts...)
}

func (g *Gateway) GetUnreadCount(ctx context.Context, in *moe.GetUnreadCountReq, opts ...grpc.CallOption) (*moe.GetUnreadCountResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUnreadCount(ctx, in)
	}
	return g.super.GetUnreadCount(ctx, in, opts...)
}

func (g *Gateway) ReadNotification(ctx context.Context, in *moe.ReadNotificationReq, opts ...grpc.CallOption) (*moe.ReadNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.ReadNotification(ctx, in)
	}
	return g.super.ReadNotification(ctx, in, opts...)
}

func (g *Gateway) ReadAllNotifications(ctx context.Context, in *moe.ReadAllNotificationsReq, opts ...grpc.CallOption) (*moe.ReadAllNotificationsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ReadAllNotifications(ctx, in)
	}
	return g.super.ReadAllNotifications(ctx, in, opts...)
}

// Super 未迁移方法仍走 RPC。
func (g *Gateway) Super() moe.SuperClient {
	if g == nil {
		return nil
	}
	return g.super
}
