package landinghttp

import (
	"context"

	landingv1 "backend/api/landing/v1"
	landingapp "backend/internal/service/landing"
)

// Server 实现 landing.v1.Landing gRPC（P4-C 试点；与 Super 并存）。
type Server struct {
	landingv1.UnimplementedLandingServer
	app *landingapp.AppService
}

// New 构造 Landing gRPC 服务。
func New(app *landingapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*landingapp.AppService, error) {
	if s.app == nil {
		return nil, errLandingAppNil
	}
	return s.app, nil
}

func (s *Server) SubmitLandingFeedback(ctx context.Context, in *landingv1.SubmitLandingFeedbackRequest) (*landingv1.SubmitLandingFeedbackReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Submit(ctx, in)
}

func (s *Server) ListLandingFeedback(ctx context.Context, in *landingv1.ListLandingFeedbackRequest) (*landingv1.ListLandingFeedbackReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.List(ctx, in)
}
