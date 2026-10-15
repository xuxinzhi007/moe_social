package gamehttp

import (
	"context"

	gamev1 "backend/api/game/v1"
	gameapp "backend/internal/service/game"
)

type Server struct {
	gamev1.UnimplementedGameServer
	app *gameapp.AppService
}

func New(app *gameapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*gameapp.AppService, error) {
	if s.app == nil {
		return nil, errGameAppNil
	}
	return s.app, nil
}

func (s *Server) InitGameSession(ctx context.Context, in *gamev1.InitGameSessionRequest) (*gamev1.InitGameSessionReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.InitGameSession(ctx, in)
}

func (s *Server) Act(ctx context.Context, in *gamev1.ActRequest) (*gamev1.ActReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Act(ctx, in)
}

func (s *Server) GetGameState(ctx context.Context, in *gamev1.GetGameStateRequest) (*gamev1.GetGameStateReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGameState(ctx, in)
}
