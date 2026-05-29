package userhttp

import (
	"context"

	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
	userapp "backend/internal/service/user"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/protobuf/types/known/emptypb"
)

// Server 实现 user.v1.UserService gRPC（P4-C；与 Super 并存）。
type Server struct {
	userv1.UnimplementedUserServiceServer
	app *userapp.AppService
}

// New 构造 User gRPC 服务。
func New(app *userapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*userapp.AppService, error) {
	if s.app == nil {
		return nil, errUserAppNil
	}
	return s.app, nil
}

func (s *Server) Login(ctx context.Context, in *userv1.LoginReq) (*userv1.LoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Login(ctx, in)
}

func (s *Server) Register(ctx context.Context, in *userv1.RegisterReq) (*userv1.RegisterResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Register(ctx, in)
}

func (s *Server) GetUserInfo(ctx context.Context, in *userv1.GetUserInfoReq) (*userv1.GetUserInfoResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserInfo(ctx, in)
}

func (s *Server) GetUser(ctx context.Context, in *userv1.GetUserReq) (*userv1.GetUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUser(ctx, in)
}

func (s *Server) UpdateUserInfo(ctx context.Context, in *userv1.UpdateUserInfoReq) (*userv1.UpdateUserInfoResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUserInfo(ctx, in)
}

func (s *Server) SyncUserDevice(ctx context.Context, in *userv1.SyncUserDeviceReq) (*userv1.SyncUserDeviceResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.SyncUserDevice(ctx, in)
}

func (s *Server) ListUserDevices(ctx context.Context, in *userv1.ListUserDevicesReq) (*userv1.ListUserDevicesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListUserDevices(ctx, in)
}

func (s *Server) ListFriends(ctx context.Context, in *userv1.ListFriendsReq) (*userv1.ListFriendsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.ListFriends(ctx, in)
}

func (s *Server) GetFriendRelation(ctx context.Context, in *userv1.GetFriendRelationReq) (*userv1.GetFriendRelationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.GetFriendRelation(ctx, in)
}

func (s *Server) SendFriendRequest(ctx context.Context, in *userv1.SendFriendRequestReq) (*userv1.SendFriendRequestResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.SendFriendRequest(ctx, in)
}

func (s *Server) AcceptFriendRequest(ctx context.Context, in *userv1.AcceptFriendRequestReq) (*userv1.AcceptFriendRequestResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.AcceptFriendRequest(ctx, in)
}

func (s *Server) RejectFriendRequest(ctx context.Context, in *userv1.RejectFriendRequestReq) (*userv1.RejectFriendRequestResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.RejectFriendRequest(ctx, in)
}

func (s *Server) ListIncomingFriendRequests(ctx context.Context, in *userv1.ListIncomingFriendRequestsReq) (*userv1.ListIncomingFriendRequestsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.ListIncomingFriendRequests(ctx, in)
}

func (s *Server) ListOutgoingFriendRequests(ctx context.Context, in *userv1.ListOutgoingFriendRequestsReq) (*userv1.ListOutgoingFriendRequestsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	in.ActorUserId = fillActorUserID(in.GetActorUserId(), in.GetUserId())
	return app.ListOutgoingFriendRequests(ctx, in)
}

func (s *Server) FeishuAuthorizeURL(ctx context.Context, in *userv1.FeishuAuthorizeURLReq) (*userv1.FeishuAuthorizeURLResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.FeishuAuthorizeURL(ctx, in)
}

func (s *Server) FeishuLogin(ctx context.Context, in *userv1.FeishuLoginReq) (*userv1.FeishuLoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.FeishuLogin(ctx, in)
}

func (s *Server) FeishuPublicConfig(ctx context.Context, _ *emptypb.Empty) (*userv1.FeishuPublicConfigResp, error) {
	cfg := utils.GetFeishuPublicConfig()
	return &userv1.FeishuPublicConfigResp{
		InviteUrl: cfg.EnterpriseInviteURL,
		HelpText:  cfg.Notice,
		Enabled:   cfg.Enabled,
	}, nil
}

func (s *Server) WechatAuthorizeURL(ctx context.Context, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.WechatAuthorizeURL(ctx, in)
}

func (s *Server) WechatLogin(ctx context.Context, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.WechatLogin(ctx, in)
}

func (s *Server) RefreshToken(ctx context.Context, _ *userv1.RefreshTokenReq) (*userv1.RefreshTokenResp, error) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return nil, errUnauthorized
	}
	tok, err := userbiz.RefreshAccessToken(req.Header.Get("Authorization"))
	if err != nil {
		return nil, err
	}
	return &userv1.RefreshTokenResp{Token: tok}, nil
}

func (s *Server) GetTransaction(ctx context.Context, in *userv1.GetTransactionReq) (*userv1.GetTransactionResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetTransaction(ctx, in)
}

func (s *Server) CheckFollow(ctx context.Context, in *userv1.CheckFollowReq) (*userv1.CheckFollowResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CheckFollow(ctx, in)
}

func (s *Server) DeleteUser(ctx context.Context, in *userv1.DeleteUserReq) (*userv1.DeleteUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteUser(ctx, in)
}

func (s *Server) FollowUser(ctx context.Context, in *userv1.FollowUserReq) (*userv1.FollowUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Follow(ctx, in)
}

func (s *Server) UnfollowUser(ctx context.Context, in *userv1.UnfollowUserReq) (*userv1.FollowUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Unfollow(ctx, in)
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

func (s *Server) UpdateUserPassword(ctx context.Context, in *userv1.UpdateUserPasswordReq) (*userv1.UpdateUserPasswordResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUserPassword(ctx, in)
}

func (s *Server) GetTransactions(ctx context.Context, in *userv1.GetTransactionsReq) (*userv1.GetTransactionsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetTransactions(ctx, in)
}

func (s *Server) Recharge(ctx context.Context, in *userv1.RechargeReq) (*userv1.RechargeResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Recharge(ctx, in)
}

func (s *Server) GetUserByEmail(ctx context.Context, in *userv1.GetUserByEmailReq) (*userv1.GetUserByEmailResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserByEmail(ctx, in)
}

func (s *Server) ResetPassword(ctx context.Context, in *userv1.ResetPasswordReq) (*userv1.ResetPasswordResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ResetPassword(ctx, in)
}

func (s *Server) GetUsers(ctx context.Context, in *userv1.GetUsersReq) (*userv1.GetUsersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUsers(ctx, in)
}

func (s *Server) GetUserCount(ctx context.Context, in *userv1.GetUserCountReq) (*userv1.GetUserCountResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserCount(ctx, in)
}

func (s *Server) DeleteMyAccount(ctx context.Context, _ *userv1.DeleteMyAccountReq) (*userv1.DeleteMyAccountResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := app.DeleteUser(ctx, &userv1.DeleteUserReq{UserId: userID}); err != nil {
		return nil, err
	}
	return &userv1.DeleteMyAccountResp{}, nil
}

func (s *Server) BindFeishu(ctx context.Context, in *userv1.BindFeishuReq) (*userv1.BindFeishuResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if in.GetUserId() == "" {
		userID, err := actorUserID(ctx)
		if err != nil {
			return nil, err
		}
		in.UserId = userID
	}
	return app.BindFeishu(ctx, in)
}

func (s *Server) UnbindFeishu(ctx context.Context, in *userv1.UnbindFeishuReq) (*userv1.UnbindFeishuResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if in.GetUserId() == "" {
		userID, err := actorUserID(ctx)
		if err != nil {
			return nil, err
		}
		in.UserId = userID
	}
	return app.UnbindFeishu(ctx, in)
}

func (s *Server) SendFeishuTestCard(ctx context.Context, in *userv1.SendFeishuTestCardReq) (*userv1.SendFeishuTestCardResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if in.GetUserId() == "" {
		userID, err := actorUserID(ctx)
		if err != nil {
			return nil, err
		}
		in.UserId = userID
	}
	return app.SendFeishuTestCard(ctx, in)
}
