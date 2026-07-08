package lifehttp

import (
	"context"

	lifev1 "backend/api/life/v1"
	lifeapp "backend/internal/service/life"
)

// Server 实现 life.v1.Life HTTP 服务。
type Server struct {
	lifev1.UnimplementedLifeServer
	app *lifeapp.AppService
}

// New 构造 Life HTTP 服务。
func New(app *lifeapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*lifeapp.AppService, error) {
	if s.app == nil {
		return nil, errLifeAppNil
	}
	return s.app, nil
}

func (s *Server) GetWorld(ctx context.Context, in *lifev1.GetLifeWorldRequest) (*lifev1.GetLifeWorldReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetWorld(ctx, in)
}

func (s *Server) ListEntities(ctx context.Context, in *lifev1.ListLifeEntitiesRequest) (*lifev1.ListLifeEntitiesReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListEntities(ctx, in)
}

func (s *Server) ListEvents(ctx context.Context, in *lifev1.ListLifeEventsRequest) (*lifev1.ListLifeEventsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListEvents(ctx, in)
}

func (s *Server) ListRelationships(ctx context.Context, in *lifev1.ListLifeRelationshipsRequest) (*lifev1.ListLifeRelationshipsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListRelationships(ctx, in)
}

func (s *Server) ApplyAction(ctx context.Context, in *lifev1.ApplyLifeActionRequest) (*lifev1.ApplyLifeActionReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ApplyAction(ctx, in)
}
