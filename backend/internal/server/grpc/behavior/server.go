package behaviorgrpc

import (
	"context"

	behaviorv1 "backend/api/behavior/v1"
	behaviorapp "backend/internal/service/behavior"
)

// Server 实现 behavior.v1.BehaviorApp gRPC/HTTP。
type Server struct {
	behaviorv1.UnimplementedBehaviorAppServer
	app *behaviorapp.AppService
}

// New 构造 Behavior gRPC/HTTP 服务。
func New(app *behaviorapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*behaviorapp.AppService, error) {
	if s.app == nil {
		return nil, errBehaviorAppNil
	}
	return s.app, nil
}

func (s *Server) TrackEvents(ctx context.Context, in *behaviorv1.TrackUserBehaviorEventsRequest) (*behaviorv1.TrackUserBehaviorEventsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.TrackEvents(ctx, in)
}
