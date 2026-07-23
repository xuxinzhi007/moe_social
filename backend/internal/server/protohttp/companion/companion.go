package companionhttp

import (
	"context"
	"errors"

	companionv1 "backend/api/companion/v1"
	companionapp "backend/internal/service/companion"
)

var errCompanionAppNil = errors.New("companion service unavailable")

type Server struct {
	companionv1.UnimplementedCompanionServer
	app *companionapp.AppService
}

func New(app *companionapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*companionapp.AppService, error) {
	if s.app == nil {
		return nil, errCompanionAppNil
	}
	return s.app, nil
}

func (s *Server) GetProfile(ctx context.Context, in *companionv1.GetProfileRequest) (*companionv1.GetProfileReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetProfile(ctx, in)
}

func (s *Server) UpsertProfile(ctx context.Context, in *companionv1.UpsertProfileRequest) (*companionv1.UpsertProfileReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpsertProfile(ctx, in)
}

func (s *Server) GetState(ctx context.Context, in *companionv1.GetStateRequest) (*companionv1.GetStateReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetState(ctx, in)
}

func (s *Server) ListMemories(ctx context.Context, in *companionv1.ListMemoriesRequest) (*companionv1.ListMemoriesReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListMemories(ctx, in)
}

func (s *Server) ListChatHistory(ctx context.Context, in *companionv1.ListChatHistoryRequest) (*companionv1.ListChatHistoryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListChatHistory(ctx, in)
}
