package chatgw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	chatv1 "backend/api/chat/v1"
	chatapp "backend/internal/service/chat"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Chat HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *chatapp.AppService
}

// New 构造网关。
func New(local *chatapp.AppService) *Gateway {
	return &Gateway{local: local}
}

// Route 当前路由。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

// SendPrivateMessage 发送私信。
func (g *Gateway) SendPrivateMessage(ctx context.Context, in *moe.SendPrivateMessageReq, opts ...grpc.CallOption) (*moe.SendPrivateMessageResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SendPrivateMessage(ctx, chatv1.SendPrivateMessageRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return chatv1.SendPrivateMessageReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

// ListPrivateMessages 私信历史。
func (g *Gateway) ListPrivateMessages(ctx context.Context, in *moe.ListPrivateMessagesReq, opts ...grpc.CallOption) (*moe.ListPrivateMessagesResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListPrivateMessages(ctx, chatv1.ListPrivateMessagesRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return chatv1.ListPrivateMessagesReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

// ListPrivateConversations 会话列表。
func (g *Gateway) ListPrivateConversations(ctx context.Context, in *moe.ListPrivateConversationsReq, opts ...grpc.CallOption) (*moe.ListPrivateConversationsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListPrivateConversations(ctx, chatv1.ListPrivateConversationsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return chatv1.ListPrivateConversationsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
