// Package userapp 关注与好友关系。
package userapp

import (
	"context"
	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
)

// Package userapp 关注与好友关系。

// Follow 关注用户。
func (s *AppService) Follow(ctx context.Context, in *userv1.FollowUserReq) (*userv1.FollowUserResp, error) {
	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.Follow(ctx, s.store, followerID, followingID); err != nil {
		return nil, err
	}
	return &userv1.FollowUserResp{Success: true}, nil
}

// Unfollow 取消关注。
func (s *AppService) Unfollow(ctx context.Context, in *userv1.UnfollowUserReq) (*userv1.FollowUserResp, error) {
	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.Unfollow(ctx, s.store, followerID, followingID); err != nil {
		return nil, err
	}
	return &userv1.FollowUserResp{Success: true}, nil
}

// CheckFollow 是否关注。
func (s *AppService) CheckFollow(ctx context.Context, in *userv1.CheckFollowReq) (*userv1.CheckFollowResp, error) {
	ok, err := userbiz.IsFollowingByStringID(ctx, s.store, in.GetFollowerId(), in.GetFollowingId())
	if err != nil {
		return nil, err
	}
	return &userv1.CheckFollowResp{IsFollowing: ok}, nil
}

// GetFollowers 粉丝列表。
func (s *AppService) GetFollowers(ctx context.Context, in *userv1.GetFollowersReq) (*userv1.GetFollowersResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	result, err := userbiz.ListFollowers(ctx, s.store, uid, userbiz.FollowListPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return followListToProto(result), nil
}

// GetFollowings 关注列表。
func (s *AppService) GetFollowings(ctx context.Context, in *userv1.GetFollowingsReq) (*userv1.GetFollowingsResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	result, err := userbiz.ListFollowings(ctx, s.store, uid, userbiz.FollowListPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return userbiz.FollowingsRespFromList(result), nil
}

// SendFriendRequest 发起好友申请。
func (s *AppService) SendFriendRequest(ctx context.Context, in *userv1.SendFriendRequestReq) (*userv1.SendFriendRequestResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	view, err := userbiz.SendFriendRequest(ctx, s.store, me, in.GetToUserId(), in.GetToMoeNo())
	if err != nil {
		return nil, err
	}
	return userbiz.SendFriendRequestRespV1(view), nil
}

// ListIncomingFriendRequests 收到的申请。
func (s *AppService) ListIncomingFriendRequests(ctx context.Context, in *userv1.ListIncomingFriendRequestsReq) (*userv1.ListIncomingFriendRequestsResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	data, err := userbiz.ListIncomingFriendRequests(ctx, s.store, me)
	if err != nil {
		return nil, err
	}
	return userbiz.ListIncomingFriendRequestsRespV1(data), nil
}

// ListOutgoingFriendRequests 发出的申请。
func (s *AppService) ListOutgoingFriendRequests(ctx context.Context, in *userv1.ListOutgoingFriendRequestsReq) (*userv1.ListOutgoingFriendRequestsResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	data, err := userbiz.ListOutgoingFriendRequests(ctx, s.store, me)
	if err != nil {
		return nil, err
	}
	return userbiz.ListOutgoingFriendRequestsRespV1(data), nil
}

// AcceptFriendRequest 同意申请。
func (s *AppService) AcceptFriendRequest(ctx context.Context, in *userv1.AcceptFriendRequestReq) (*userv1.AcceptFriendRequestResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.AcceptFriendRequest(ctx, s.store, me, in.GetRequestId()); err != nil {
		return nil, err
	}
	return &userv1.AcceptFriendRequestResp{Ok: true}, nil
}

// RejectFriendRequest 拒绝申请。
func (s *AppService) RejectFriendRequest(ctx context.Context, in *userv1.RejectFriendRequestReq) (*userv1.RejectFriendRequestResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.RejectFriendRequest(ctx, s.store, me, in.GetRequestId()); err != nil {
		return nil, err
	}
	return &userv1.RejectFriendRequestResp{Ok: true}, nil
}

// ListFriends 好友列表。
func (s *AppService) ListFriends(ctx context.Context, in *userv1.ListFriendsReq) (*userv1.ListFriendsResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	users, err := userbiz.ListFriends(ctx, s.store, me)
	if err != nil {
		return nil, err
	}
	return userbiz.ListFriendsRespV1(users), nil
}

// GetFriendRelation 好友关系状态。
func (s *AppService) GetFriendRelation(ctx context.Context, in *userv1.GetFriendRelationReq) (*userv1.GetFriendRelationResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	other, err := parseUserID(in.GetOtherUserId())
	if err != nil {
		return nil, err
	}
	rel, err := userbiz.GetFriendRelation(ctx, s.store, me, other)
	if err != nil {
		return nil, err
	}
	return userbiz.GetFriendRelationRespV1(rel), nil
}

func followListToProto(result userbiz.FollowListResult) *userv1.GetFollowersResp {
	return userbiz.FollowersRespV1(result)
}
