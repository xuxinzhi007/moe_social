package userhttp

import (
	"context"

	userv1 "backend/api/user/v1"
	apicomm "backend/internal/platform/apicomm"
)

func (s *Server) FollowUser(ctx context.Context, in *userv1.FollowUserReq) (*userv1.FollowUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.Follow(ctx, in)
}

func (s *Server) UnfollowUser(ctx context.Context, in *userv1.UnfollowUserReq) (*userv1.FollowUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.Unfollow(ctx, in)
}

func (s *Server) CheckFollow(ctx context.Context, in *userv1.CheckFollowReq) (*userv1.CheckFollowResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CheckFollow(ctx, in)
}

func (s *Server) GetFollowers(ctx context.Context, in *userv1.GetFollowersReq) (*userv1.GetFollowersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetFollowers(ctx, in)
}

func (s *Server) GetFollowings(ctx context.Context, in *userv1.GetFollowingsReq) (*userv1.GetFollowingsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetFollowings(ctx, in)
}

func (s *Server) ListFriends(ctx context.Context, in *userv1.ListFriendsReq) (*userv1.ListFriendsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claimed := fillActorUserID(in.GetActorUserId(), in.GetUserId())
	uid, err := apicomm.RequireSelfOrUnbound(ctx, claimed)
	if err != nil {
		return nil, err
	}
	in.ActorUserId = uid
	return app.ListFriends(ctx, in)
}

func (s *Server) GetFriendRelation(ctx context.Context, in *userv1.GetFriendRelationReq) (*userv1.GetFriendRelationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claimed := fillActorUserID(in.GetActorUserId(), in.GetUserId())
	uid, err := apicomm.RequireSelfOrUnbound(ctx, claimed)
	if err != nil {
		return nil, err
	}
	in.ActorUserId = uid
	return app.GetFriendRelation(ctx, in)
}

func (s *Server) SendFriendRequest(ctx context.Context, in *userv1.SendFriendRequestReq) (*userv1.SendFriendRequestResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claimed := fillActorUserID(in.GetActorUserId(), in.GetUserId())
	uid, err := apicomm.RequireSelfOrUnbound(ctx, claimed)
	if err != nil {
		return nil, err
	}
	in.ActorUserId = uid
	return app.SendFriendRequest(ctx, in)
}

func (s *Server) AcceptFriendRequest(ctx context.Context, in *userv1.AcceptFriendRequestReq) (*userv1.AcceptFriendRequestResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claimed := fillActorUserID(in.GetActorUserId(), in.GetUserId())
	uid, err := apicomm.RequireSelfOrUnbound(ctx, claimed)
	if err != nil {
		return nil, err
	}
	in.ActorUserId = uid
	return app.AcceptFriendRequest(ctx, in)
}

func (s *Server) RejectFriendRequest(ctx context.Context, in *userv1.RejectFriendRequestReq) (*userv1.RejectFriendRequestResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claimed := fillActorUserID(in.GetActorUserId(), in.GetUserId())
	uid, err := apicomm.RequireSelfOrUnbound(ctx, claimed)
	if err != nil {
		return nil, err
	}
	in.ActorUserId = uid
	return app.RejectFriendRequest(ctx, in)
}

func (s *Server) ListIncomingFriendRequests(ctx context.Context, in *userv1.ListIncomingFriendRequestsReq) (*userv1.ListIncomingFriendRequestsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claimed := fillActorUserID(in.GetActorUserId(), in.GetUserId())
	uid, err := apicomm.RequireSelfOrUnbound(ctx, claimed)
	if err != nil {
		return nil, err
	}
	in.ActorUserId = uid
	return app.ListIncomingFriendRequests(ctx, in)
}
