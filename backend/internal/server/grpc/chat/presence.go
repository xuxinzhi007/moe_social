package chatgrpc

import (
	"context"
	"strings"

	chatv1 "backend/api/chat/v1"
	"backend/internal/apilegacy/presence"
)

// PresenceServer 实现 chat.v1.ChatPresenceService HTTP。
type PresenceServer struct {
	chatv1.UnimplementedChatPresenceServiceServer
}

// NewPresence 构造在线状态 HTTP 服务。
func NewPresence() *PresenceServer {
	return &PresenceServer{}
}

func (s *PresenceServer) GetChatOnline(_ context.Context, in *chatv1.GetChatOnlineReq) (*chatv1.GetChatOnlineResp, error) {
	return &chatv1.GetChatOnlineResp{
		Online: presence.DefaultState.IsOnline(in.GetUserId()),
	}, nil
}

func (s *PresenceServer) GetChatOnlineBatch(_ context.Context, in *chatv1.GetChatOnlineBatchReq) (*chatv1.GetChatOnlineBatchResp, error) {
	ids := make([]string, 0)
	if in.GetUserIds() != "" {
		for _, part := range strings.Split(in.GetUserIds(), ",") {
			id := strings.TrimSpace(part)
			if id == "" {
				continue
			}
			ids = append(ids, id)
		}
	}
	online := make(map[string]bool, len(ids))
	for _, id := range ids {
		online[id] = presence.DefaultState.IsOnline(id)
	}
	return &chatv1.GetChatOnlineBatchResp{Online: online}, nil
}
