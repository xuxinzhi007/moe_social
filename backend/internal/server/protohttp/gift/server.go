package gifthttp

import (
	"context"

	giftv1 "backend/api/gift/v1"
	giftapp "backend/internal/service/gift"
)

// Server 实现 gift.v1.GiftService gRPC（P4-C；与 Super 并存）。
type Server struct {
	giftv1.UnimplementedGiftServiceServer
	app *giftapp.AppService
}

// New 构造 Gift gRPC 服务。
func New(app *giftapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*giftapp.AppService, error) {
	if s.app == nil {
		return nil, errGiftAppNil
	}
	return s.app, nil
}

func (s *Server) GetGifts(ctx context.Context, in *giftv1.GetGiftsRequest) (*giftv1.GetGiftsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGifts(ctx, in)
}

func (s *Server) GetGift(ctx context.Context, in *giftv1.GetGiftRequest) (*giftv1.GetGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGift(ctx, in)
}

func (s *Server) SendGift(ctx context.Context, in *giftv1.SendGiftRequest) (*giftv1.SendGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.SendGift(ctx, in)
}

func (s *Server) PurchaseGift(ctx context.Context, in *giftv1.PurchaseGiftRequest) (*giftv1.PurchaseGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.PurchaseGift(ctx, in)
}

func (s *Server) GetGiftRecords(ctx context.Context, in *giftv1.GetGiftRecordsRequest) (*giftv1.GetGiftRecordsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGiftRecords(ctx, in)
}

func (s *Server) GetGiftPurchaseOrders(ctx context.Context, in *giftv1.GetGiftPurchaseOrdersRequest) (*giftv1.GetGiftPurchaseOrdersReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetGiftPurchaseOrders(ctx, in)
}
