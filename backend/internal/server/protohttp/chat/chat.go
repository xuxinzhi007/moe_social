package chathttp

import (
	"context"

	chatv1 "backend/api/chat/v1"
	chatapp "backend/internal/service/chat"
)

// Server 实现 chat.v1.PrivateMessageService / PushNotificationService gRPC（P4-C；与 Super 并存）。
type Server struct {
	chatv1.UnimplementedPrivateMessageServiceServer
	chatv1.UnimplementedPushNotificationServiceServer
	app *chatapp.AppService
}

// New 构造 Chat gRPC 服务。
func New(app *chatapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*chatapp.AppService, error) {
	if s.app == nil {
		return nil, errChatAppNil
	}
	return s.app, nil
}

func (s *Server) SendPrivateMessage(ctx context.Context, in *chatv1.SendPrivateMessageRequest) (*chatv1.SendPrivateMessageReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if err := fillSendPrivateMessageRequest(ctx, in); err != nil {
		return nil, err
	}
	return app.SendPrivateMessage(ctx, in)
}

func (s *Server) ListPrivateMessages(ctx context.Context, in *chatv1.ListPrivateMessagesRequest) (*chatv1.ListPrivateMessagesReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if err := fillPrivateMessageListRequest(ctx, in); err != nil {
		return nil, err
	}
	return app.ListPrivateMessages(ctx, in)
}

func (s *Server) ListPrivateConversations(ctx context.Context, in *chatv1.ListPrivateConversationsRequest) (*chatv1.ListPrivateConversationsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if err := fillPrivateConversationsRequest(ctx, in); err != nil {
		return nil, err
	}
	return app.ListPrivateConversations(ctx, in)
}
