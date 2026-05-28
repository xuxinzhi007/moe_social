package notifygrpc

import (
	"context"

	notifyv1 "backend/api/notify/v1"
	notifyapp "backend/internal/service/notify"
	moerpc "backend/rpc/pb/moe"
)

// Server 实现 notify.v1.NotifyService gRPC（P4-C；与 Super 并存）。
type Server struct {
	notifyv1.UnimplementedNotifyServiceServer
	app *notifyapp.AppService
}

// New 构造 Notify gRPC 服务。
func New(app *notifyapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*notifyapp.AppService, error) {
	if s.app == nil {
		return nil, errNotifyAppNil
	}
	return s.app, nil
}

func (s *Server) GetNotifications(ctx context.Context, in *notifyv1.GetNotificationsRequest) (*notifyv1.GetNotificationsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetNotifications(ctx, &moerpc.GetNotificationsReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return &notifyv1.GetNotificationsReply{
		Notifications: notificationsToProto(resp.GetNotifications()),
		Total:         resp.GetTotal(),
	}, nil
}

func (s *Server) GetUnreadCount(ctx context.Context, in *notifyv1.GetUnreadCountRequest) (*notifyv1.GetUnreadCountReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUnreadCount(ctx, &moerpc.GetUnreadCountReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &notifyv1.GetUnreadCountReply{Count: resp.GetCount()}, nil
}

func (s *Server) ReadNotification(ctx context.Context, in *notifyv1.ReadNotificationRequest) (*notifyv1.ReadNotificationReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	_, err = app.ReadNotification(ctx, &moerpc.ReadNotificationReq{Id: in.GetId(), UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &notifyv1.ReadNotificationReply{}, nil
}

func (s *Server) ReadAllNotifications(ctx context.Context, in *notifyv1.ReadAllNotificationsRequest) (*notifyv1.ReadAllNotificationsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	_, err = app.ReadAllNotifications(ctx, &moerpc.ReadAllNotificationsReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &notifyv1.ReadAllNotificationsReply{}, nil
}
