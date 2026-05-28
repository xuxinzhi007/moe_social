package landinggrpc

import (
	"context"

	landingv1 "backend/api/landing/v1"
	landingapp "backend/internal/service/landing"
	"backend/rpc/pb/moe"
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
	resp, err := app.Submit(ctx, &moe.SubmitLandingFeedbackReq{
		Email:     in.GetEmail(),
		Category:  in.GetCategory(),
		Content:   in.GetContent(),
		Source:    in.GetSource(),
		ClientIp:  in.GetClientIp(),
		UserAgent: in.GetUserAgent(),
	})
	if err != nil {
		return nil, err
	}
	return &landingv1.SubmitLandingFeedbackReply{Id: resp.GetId()}, nil
}

func (s *Server) ListLandingFeedback(ctx context.Context, in *landingv1.ListLandingFeedbackRequest) (*landingv1.ListLandingFeedbackReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.List(ctx, &moe.ListLandingFeedbackReq{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
		Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	items := make([]*landingv1.LandingFeedbackItem, 0, len(resp.GetItems()))
	for _, row := range resp.GetItems() {
		items = append(items, &landingv1.LandingFeedbackItem{
			Id:        row.GetId(),
			Email:     row.GetEmail(),
			Category:  row.GetCategory(),
			Content:   row.GetContent(),
			Source:    row.GetSource(),
			ClientIp:  row.GetClientIp(),
			UserAgent: row.GetUserAgent(),
			CreatedAt: row.GetCreatedAt(),
		})
	}
	return &landingv1.ListLandingFeedbackReply{Items: items, Total: resp.GetTotal()}, nil
}
