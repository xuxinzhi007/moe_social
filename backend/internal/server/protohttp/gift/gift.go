package gifthttp

import (
	"context"

	giftv1 "backend/api/gift/v1"
	apicomm "backend/internal/platform/apicomm"
	giftapp "backend/internal/service/gift"
)

// Server 实现 gift.v1.GiftService HTTP/gRPC 适配。
type Server struct {
	giftv1.UnimplementedGiftServiceServer
	app *giftapp.AppService
}

// New 构造 Gift 服务。
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
	if in.GetViewerUserId() == "" {
		in.ViewerUserId = apicomm.ResolveActorUserID(ctx, "")
	}
	return app.GetGifts(ctx, in)
}

func (s *Server) SendGift(ctx context.Context, in *giftv1.SendGiftRequest) (*giftv1.SendGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetFromUserId())
	if err != nil {
		return nil, err
	}
	in.FromUserId = uid
	out, err := app.SendGift(ctx, in)
	if err != nil {
		return nil, mapGiftError(err)
	}
	return out, nil
}

func (s *Server) PurchaseGift(ctx context.Context, in *giftv1.PurchaseGiftRequest) (*giftv1.PurchaseGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	out, err := app.PurchaseGift(ctx, in)
	if err != nil {
		return nil, mapGiftError(err)
	}
	return out, nil
}

func (s *Server) GetGiftPurchaseOrders(ctx context.Context, in *giftv1.GetGiftPurchaseOrdersRequest) (*giftv1.GetGiftPurchaseOrdersReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	out, err := app.GetGiftPurchaseOrders(ctx, in)
	if err != nil {
		return nil, mapGiftError(err)
	}
	return out, nil
}
