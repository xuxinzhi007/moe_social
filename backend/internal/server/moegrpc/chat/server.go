package chatgrpc

import (
	"context"

	chatv1 "backend/api/chat/v1"
	chatapp "backend/internal/service/chat"
	moerpc "backend/rpc/pb/moe"
)

// Server 实现 chat.v1.PrivateMessageService gRPC（P4-C；与 Super 并存）。
type Server struct {
	chatv1.UnimplementedPrivateMessageServiceServer
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
	resp, err := app.SendPrivateMessage(ctx, &moerpc.SendPrivateMessageReq{
		SenderId: in.GetSenderId(), ReceiverId: in.GetReceiverId(),
		Body: in.GetBody(), ImagePaths: in.GetImagePaths(),
	})
	if err != nil {
		return nil, err
	}
	return &chatv1.SendPrivateMessageReply{Message: privateMessageToProto(resp.GetMessage())}, nil
}

func (s *Server) ListPrivateMessages(ctx context.Context, in *chatv1.ListPrivateMessagesRequest) (*chatv1.ListPrivateMessagesReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.ListPrivateMessages(ctx, &moerpc.ListPrivateMessagesReq{
		ViewerId: in.GetViewerId(), PeerId: in.GetPeerId(),
		BeforeId: in.GetBeforeId(), Limit: in.GetLimit(),
	})
	if err != nil {
		return nil, err
	}
	return &chatv1.ListPrivateMessagesReply{
		Messages: privateMessagesToProto(resp.GetMessages()), HasMore: resp.GetHasMore(),
	}, nil
}

func (s *Server) ListPrivateConversations(ctx context.Context, in *chatv1.ListPrivateConversationsRequest) (*chatv1.ListPrivateConversationsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.ListPrivateConversations(ctx, &moerpc.ListPrivateConversationsReq{
		ViewerId: in.GetViewerId(), Limit: in.GetLimit(), Offset: in.GetOffset(),
	})
	if err != nil {
		return nil, err
	}
	return &chatv1.ListPrivateConversationsReply{
		Conversations: conversationsToProto(resp.GetConversations()),
		Total: resp.GetTotal(), Limit: resp.GetLimit(), Offset: resp.GetOffset(),
		HasMore: resp.GetHasMore(),
	}, nil
}
