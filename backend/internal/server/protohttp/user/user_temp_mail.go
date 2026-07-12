package userhttp

import (
	"context"

	userv1 "backend/api/user/v1"
)

func (s *Server) GenerateTempEmail(ctx context.Context, in *userv1.GenerateTempEmailReq) (*userv1.GenerateTempEmailResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GenerateTempEmail(ctx, in)
}

func (s *Server) GetTempEmailLatestCode(ctx context.Context, in *userv1.GetTempEmailLatestCodeReq) (*userv1.GetTempEmailLatestCodeResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetTempEmailLatestCode(ctx, in)
}
