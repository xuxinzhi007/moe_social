package usergw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	userapp "backend/internal/service/user"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway User HTTP→biz 或 super RPC 回退。
type Gateway struct {
	local *userapp.AppService
}

// New 构造网关。
func New(local *userapp.AppService) *Gateway {
	return &Gateway{local: local}
}

// Route 当前路由。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) Login(ctx context.Context, in *moe.LoginReq, opts ...grpc.CallOption) (*moe.LoginResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.Login(ctx, userv1.LoginReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.LoginRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) Register(ctx context.Context, in *moe.RegisterReq, opts ...grpc.CallOption) (*moe.RegisterResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.Register(ctx, userv1.RegisterReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.RegisterRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserInfo(ctx context.Context, in *moe.GetUserInfoReq, opts ...grpc.CallOption) (*moe.GetUserInfoResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserInfo(ctx, userv1.GetUserInfoReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUserInfoRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUser(ctx context.Context, in *moe.GetUserReq, opts ...grpc.CallOption) (*moe.GetUserResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUser(ctx, userv1.GetUserReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUserRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserVipStatus(ctx context.Context, in *moe.GetUserVipStatusReq, opts ...grpc.CallOption) (*moe.GetUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserVipStatus(ctx, vipv1.GetUserVipStatusReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.GetUserVipStatusRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetVipOrders(ctx context.Context, in *moe.GetVipOrdersReq, opts ...grpc.CallOption) (*moe.GetVipOrdersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetVipOrders(ctx, vipv1.GetVipOrdersReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.GetVipOrdersRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CheckUserVip(ctx context.Context, in *moe.CheckUserVipReq, opts ...grpc.CallOption) (*moe.CheckUserVipResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CheckUserVip(ctx, vipv1.CheckUserVipReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.CheckUserVipRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) FollowUser(ctx context.Context, in *moe.FollowUserReq, opts ...grpc.CallOption) (*moe.FollowUserResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.Follow(ctx, userv1.FollowUserReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.FollowUserRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UnfollowUser(ctx context.Context, in *moe.UnfollowUserReq, opts ...grpc.CallOption) (*moe.FollowUserResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.Unfollow(ctx, userv1.UnfollowUserReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.FollowUserRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CheckFollow(ctx context.Context, in *moe.CheckFollowReq, opts ...grpc.CallOption) (*moe.CheckFollowResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CheckFollow(ctx, userv1.CheckFollowReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.CheckFollowRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetFollowers(ctx context.Context, in *moe.GetFollowersReq, opts ...grpc.CallOption) (*moe.GetFollowersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetFollowers(ctx, userv1.GetFollowersReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetFollowersRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetFollowings(ctx context.Context, in *moe.GetFollowingsReq, opts ...grpc.CallOption) (*moe.GetFollowingsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetFollowings(ctx, userv1.GetFollowingsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetFollowingsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SendFriendRequest(ctx context.Context, in *moe.SendFriendRequestReq, opts ...grpc.CallOption) (*moe.SendFriendRequestResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SendFriendRequest(ctx, userv1.SendFriendRequestReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.SendFriendRequestRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListIncomingFriendRequests(ctx context.Context, in *moe.ListIncomingFriendRequestsReq, opts ...grpc.CallOption) (*moe.ListIncomingFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListIncomingFriendRequests(ctx, userv1.ListIncomingFriendRequestsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ListIncomingFriendRequestsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListOutgoingFriendRequests(ctx context.Context, in *moe.ListOutgoingFriendRequestsReq, opts ...grpc.CallOption) (*moe.ListOutgoingFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListOutgoingFriendRequests(ctx, userv1.ListOutgoingFriendRequestsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ListOutgoingFriendRequestsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AcceptFriendRequest(ctx context.Context, in *moe.AcceptFriendRequestReq, opts ...grpc.CallOption) (*moe.AcceptFriendRequestResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AcceptFriendRequest(ctx, userv1.AcceptFriendRequestReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.AcceptFriendRequestRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) RejectFriendRequest(ctx context.Context, in *moe.RejectFriendRequestReq, opts ...grpc.CallOption) (*moe.RejectFriendRequestResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.RejectFriendRequest(ctx, userv1.RejectFriendRequestReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.RejectFriendRequestRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListFriends(ctx context.Context, in *moe.ListFriendsReq, opts ...grpc.CallOption) (*moe.ListFriendsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListFriends(ctx, userv1.ListFriendsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ListFriendsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetFriendRelation(ctx context.Context, in *moe.GetFriendRelationReq, opts ...grpc.CallOption) (*moe.GetFriendRelationResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetFriendRelation(ctx, userv1.GetFriendRelationReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetFriendRelationRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetNotifications(ctx context.Context, in *moe.GetNotificationsReq, opts ...grpc.CallOption) (*moe.GetNotificationsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetNotifications(ctx, userv1.GetNotificationsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetNotificationsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUnreadCount(ctx context.Context, in *moe.GetUnreadCountReq, opts ...grpc.CallOption) (*moe.GetUnreadCountResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUnreadCount(ctx, userv1.GetUnreadCountReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUnreadCountRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ReadNotification(ctx context.Context, in *moe.ReadNotificationReq, opts ...grpc.CallOption) (*moe.ReadNotificationResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ReadNotification(ctx, userv1.ReadNotificationReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ReadNotificationRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ReadAllNotifications(ctx context.Context, in *moe.ReadAllNotificationsReq, opts ...grpc.CallOption) (*moe.ReadAllNotificationsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ReadAllNotifications(ctx, userv1.ReadAllNotificationsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ReadAllNotificationsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
