package moehttp

import (
	"context"

	hchat "backend/api/internal/handler/chat"
	chatlogic "backend/api/internal/logic/chat"
	privatemsglogic "backend/api/internal/logic/privatemsg"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeChatCompatRoutes 私信 + 在线/WS（WS 仍走 goctl handler 以保留 ResponseWriter 上下文）。
const PilotNativeChatCompatRoutes = 9

func RegisterChatCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.POST("/api/private-messages", pmSendPrivateMessage(svcCtx))
	r.GET("/api/private-messages", pmListPrivateMessages(svcCtx))
	r.GET("/api/private-messages/conversations", pmListPrivateConversations(svcCtx))
	r.GET("/api/chat/online", chatChatOnline(svcCtx))
	r.GET("/api/chat/online/batch", chatChatOnlineBatch(svcCtx))
	r.GET("/ws/chat", wrapNativeHTTP(hchat.ChatWsHandler(svcCtx)))
	r.GET("/ws/presence", wrapNativeHTTP(hchat.PresenceWsHandler(svcCtx)))
	r.GET("/ws/remote", wrapNativeHTTP(hchat.RemoteWsHandler(svcCtx)))
	r.GET("/ws/world", wrapNativeHTTP(hchat.WorldWsHandler(svcCtx)))
}

func pmSendPrivateMessage(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.SendPrivateMessageReq) (any, error) {
		l := privatemsglogic.NewSendPrivateMessageLogic(ctx, svcCtx)
		return l.SendPrivateMessage(req)
	})
}

func pmListPrivateMessages(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ListPrivateMessagesReq) (any, error) {
		l := privatemsglogic.NewListPrivateMessagesLogic(ctx, svcCtx)
		return l.ListPrivateMessages(req)
	})
}

func pmListPrivateConversations(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ListPrivateConversationsReq) (any, error) {
		l := privatemsglogic.NewListPrivateConversationsLogic(ctx, svcCtx)
		return l.ListPrivateConversations(req)
	})
}

func chatChatOnline(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ChatOnlineReq) (any, error) {
		l := chatlogic.NewChatOnlineLogic(ctx, svcCtx)
		return l.ChatOnline(req)
	})
}

func chatChatOnlineBatch(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ChatOnlineBatchReq) (any, error) {
		l := chatlogic.NewChatOnlineBatchLogic(ctx, svcCtx)
		return l.ChatOnlineBatch(req)
	})
}
