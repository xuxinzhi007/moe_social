package giftgrpc

import (
	"context"

	giftv1 "backend/api/gift/v1"
	giftapp "backend/internal/service/gift"
	moerpc "backend/rpc/pb/moe"
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
	resp, err := app.GetGifts(ctx, &moerpc.GetGiftsReq{
		Page: in.GetPage(), PageSize: in.GetPageSize(), ViewerUserId: in.GetViewerUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftsReply{Gifts: giftsToProto(resp.GetGifts()), Total: resp.GetTotal()}, nil
}

func (s *Server) GetGift(ctx context.Context, in *giftv1.GetGiftRequest) (*giftv1.GetGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetGift(ctx, &moerpc.GetGiftReq{GiftId: in.GetGiftId()})
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftReply{
		Success: resp.GetSuccess(), Message: resp.GetMessage(), Gift: giftToProto(resp.GetGift()),
	}, nil
}

func (s *Server) SendGift(ctx context.Context, in *giftv1.SendGiftRequest) (*giftv1.SendGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.SendGift(ctx, &moerpc.SendGiftReq{
		FromUserId: in.GetFromUserId(), ToUserId: in.GetToUserId(),
		GiftId: in.GetGiftId(), Quantity: in.GetQuantity(),
	})
	if err != nil {
		return nil, err
	}
	return &giftv1.SendGiftReply{
		Success: resp.GetSuccess(), Message: resp.GetMessage(),
		Record:          giftRecordToProto(resp.GetRecord()),
		NewAchievements: achievementUnlocksToProto(resp.GetNewAchievements()),
	}, nil
}

func (s *Server) PurchaseGift(ctx context.Context, in *giftv1.PurchaseGiftRequest) (*giftv1.PurchaseGiftReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.PurchaseGift(ctx, &moerpc.PurchaseGiftReq{
		UserId: in.GetUserId(), GiftId: in.GetGiftId(), Quantity: in.GetQuantity(),
	})
	if err != nil {
		return nil, err
	}
	return &giftv1.PurchaseGiftReply{
		Success: resp.GetSuccess(), Message: resp.GetMessage(), NewBalance: resp.GetNewBalance(),
		OwnedQuantity: resp.GetOwnedQuantity(), OrderNo: resp.GetOrderNo(),
	}, nil
}

func (s *Server) GetGiftRecords(ctx context.Context, in *giftv1.GetGiftRecordsRequest) (*giftv1.GetGiftRecordsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetGiftRecords(ctx, &moerpc.GetGiftRecordsReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return &giftv1.GetGiftRecordsReply{
		Records: giftRecordsToProto(resp.GetRecords()), Total: resp.GetTotal(),
	}, nil
}
