package chatgw

import (
	"context"

	chatapp "backend/internal/service/chat"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Chat HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *chatapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *chatapp.AppService, legacy moe.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

// SendPrivateMessage 发送私信。
func (g *Gateway) SendPrivateMessage(ctx context.Context, in *moe.SendPrivateMessageReq, opts ...grpc.CallOption) (*moe.SendPrivateMessageResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendPrivateMessage(ctx, in)
	}
	return g.super.SendPrivateMessage(ctx, in, opts...)
}

// ListPrivateMessages 私信历史。
func (g *Gateway) ListPrivateMessages(ctx context.Context, in *moe.ListPrivateMessagesReq, opts ...grpc.CallOption) (*moe.ListPrivateMessagesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPrivateMessages(ctx, in)
	}
	return g.super.ListPrivateMessages(ctx, in, opts...)
}

// ListPrivateConversations 会话列表。
func (g *Gateway) ListPrivateConversations(ctx context.Context, in *moe.ListPrivateConversationsReq, opts ...grpc.CallOption) (*moe.ListPrivateConversationsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPrivateConversations(ctx, in)
	}
	return g.super.ListPrivateConversations(ctx, in, opts...)
}
