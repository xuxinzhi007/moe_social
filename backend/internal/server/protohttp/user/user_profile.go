package userhttp

import (
	"context"

	userv1 "backend/api/user/v1"
)

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

func (s *Server) UpdateUserPassword(ctx context.Context, in *userv1.UpdateUserPasswordReq) (*userv1.UpdateUserPasswordResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUserPassword(ctx, in)
}

func (s *Server) ResetPassword(ctx context.Context, in *userv1.ResetPasswordReq) (*userv1.ResetPasswordResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ResetPassword(ctx, in)
}

func (s *Server) DeleteUser(ctx context.Context, in *userv1.DeleteUserReq) (*userv1.DeleteUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteUser(ctx, in)
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

func (s *Server) GetUserByEmail(ctx context.Context, in *userv1.GetUserByEmailReq) (*userv1.GetUserByEmailResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserByEmail(ctx, in)
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
