package battlehttp

import (
	"context"

	battlev1 "backend/api/battle/v1"
	battleapp "backend/internal/service/battle"
)

// Server implements the generated battle HTTP and gRPC contract.
type Server struct {
	battlev1.UnimplementedBattleServiceServer
	app *battleapp.AppService
}

func New(app *battleapp.AppService) *Server { return &Server{app: app} }
func (s *Server) CreateRoom(ctx context.Context, in *battlev1.CreateRoomRequest) (*battlev1.BattleRoomReply, error) {
	return s.app.CreateRoom(ctx, in)
}
func (s *Server) GetRoom(ctx context.Context, in *battlev1.GetRoomRequest) (*battlev1.BattleRoomReply, error) {
	return s.app.GetRoom(ctx, in)
}
func (s *Server) StartRoom(ctx context.Context, in *battlev1.StartRoomRequest) (*battlev1.BattleRoomReply, error) {
	return s.app.StartRoom(ctx, in)
}
func (s *Server) SendBattleGift(ctx context.Context, in *battlev1.SendBattleGiftRequest) (*battlev1.SendBattleGiftReply, error) {
	return s.app.SendBattleGift(ctx, in)
}
func (s *Server) FinishRoom(ctx context.Context, in *battlev1.FinishRoomRequest) (*battlev1.BattleRoomReply, error) {
	return s.app.FinishRoom(ctx, in)
}
