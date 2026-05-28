package moehttp

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/presence"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	chatbiz "backend/internal/biz/chat"
	chatapp "backend/internal/service/chat"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeChatCompatRoutes 私信 + 在线 + WS（tier-A；WS 直挂 chatbiz）。
const PilotNativeChatCompatRoutes = 9

func RegisterChatCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")

	r.GET("/ws/chat", chatWSHandler(svcCtx))
	r.GET("/ws/presence", chatPresenceWSHandler())
	r.GET("/ws/remote", chatRemoteWS())
	r.GET("/ws/world", chatWorldWSHandler())

	r.GET("/api/chat/online", chatChatOnline())
	r.GET("/api/chat/online/batch", chatChatOnlineBatch())

	app := svcCtx.ChatApp
	if app == nil {
		return
	}

	r.POST("/api/private-messages", pmSendPrivateMessage(svcCtx, app))
	r.GET("/api/private-messages", pmListPrivateMessages(app))
	r.GET("/api/private-messages/conversations", pmListPrivateConversations(app))
}

func pmSendPrivateMessage(svcCtx *svc.ServiceContext, app *chatapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SendPrivateMessageReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SendPrivateMessageResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		senderID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.SendPrivateMessageResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		rpcResp, err := app.SendPrivateMessage(ctx, &moe.SendPrivateMessageReq{
			SenderId:   senderID,
			ReceiverId: req.ReceiverId,
			Body:       req.Body,
			ImagePaths: req.ImagePaths,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SendPrivateMessageResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
		}
		if rpcResp.Message == nil {
			return ctx.JSON(http.StatusOK, types.SendPrivateMessageResp{
				BaseResp: common.HandleRPCError(nil, "发送失败"),
			})
		}

		deliveryDeps := chatDeliveryDeps(svcCtx)
		senderName, senderAvatar := chatbiz.ResolvePrivateMessageSenderProfile(
			ctx, deliveryDeps, senderID, rpcResp.Message, "",
		)
		chatbiz.DeliverPrivateMessageRealTime(ctx, deliveryDeps, senderID, req.ReceiverId, req.Body, senderName, senderAvatar, rpcResp.Message)

		return ctx.JSON(http.StatusOK, types.SendPrivateMessageResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     privateMessageItemFromProto(rpcResp.Message),
		})
	}
}

func pmListPrivateMessages(app *chatapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ListPrivateMessagesReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ListPrivateMessagesResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		viewerID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.ListPrivateMessagesResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		rpcResp, err := app.ListPrivateMessages(ctx, &moe.ListPrivateMessagesReq{
			ViewerId: viewerID,
			PeerId:   req.PeerUserId,
			BeforeId: req.BeforeId,
			Limit:    int32(req.Limit),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListPrivateMessagesResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
		}
		items := make([]types.PrivateMessageItem, 0, len(rpcResp.Messages))
		for _, m := range rpcResp.Messages {
			if m == nil {
				continue
			}
			items = append(items, privateMessageItemFromProto(m))
		}
		return ctx.JSON(http.StatusOK, types.ListPrivateMessagesResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
			HasMore:  rpcResp.HasMore,
		})
	}
}

func pmListPrivateConversations(app *chatapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ListPrivateConversationsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ListPrivateConversationsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		viewerID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.ListPrivateConversationsResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		rpcResp, err := app.ListPrivateConversations(ctx, &moe.ListPrivateConversationsReq{
			ViewerId: viewerID,
			Limit:    int32(req.Limit),
			Offset:   int32(req.Offset),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListPrivateConversationsResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
		}
		items := make([]types.PrivateConversationItem, 0, len(rpcResp.Conversations))
		for _, c := range rpcResp.Conversations {
			if c == nil {
				continue
			}
			items = append(items, privateConversationItemFromProto(c))
		}
		return ctx.JSON(http.StatusOK, types.ListPrivateConversationsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
			Total:    int(rpcResp.GetTotal()),
			Limit:    int(rpcResp.GetLimit()),
			Offset:   int(rpcResp.GetOffset()),
			HasMore:  rpcResp.GetHasMore(),
		})
	}
}

func chatChatOnline() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ChatOnlineReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ChatOnlineResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		online := presence.DefaultState.IsOnline(req.UserId)
		return ctx.JSON(http.StatusOK, types.ChatOnlineResp{
			BaseResp: types.BaseResp{Code: 200, Message: "success", Success: true},
			Online:   online,
		})
	}
}

func chatChatOnlineBatch() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ChatOnlineBatchReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ChatOnlineBatchResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		ids := make([]string, 0)
		if req.UserIds != "" {
			for _, part := range strings.Split(req.UserIds, ",") {
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
		return ctx.JSON(http.StatusOK, types.ChatOnlineBatchResp{
			BaseResp: types.BaseResp{Code: 200, Message: "success", Success: true},
			Online:   online,
		})
	}
}

func chatDeliveryDeps(svcCtx *svc.ServiceContext) chatbiz.DeliveryDeps {
	deps := chatbiz.DeliveryDeps{UserReader: svcCtx.UserGW, NotifyRPC: svcCtx.UserGW}
	if svcCtx.UserApp != nil {
		deps.NotifyStore = svcCtx.UserApp.Notify()
	}
	return deps
}

func privateMessageItemFromProto(m *moe.PrivateMessage) types.PrivateMessageItem {
	paths := m.GetImagePaths()
	if paths == nil {
		paths = []string{}
	}
	return types.PrivateMessageItem{
		Id:            m.GetId(),
		SenderId:      m.GetSenderId(),
		ReceiverId:    m.GetReceiverId(),
		SenderMoeNo:   m.GetSenderMoeNo(),
		ReceiverMoeNo: m.GetReceiverMoeNo(),
		Body:          m.GetBody(),
		ImagePaths:    paths,
		RetentionDays: int(m.GetRetentionDays()),
		CreatedAt:     m.GetCreatedAt(),
		ExpiresAt:     m.GetExpiresAt(),
	}
}

func privateConversationItemFromProto(c *moe.PrivateConversation) types.PrivateConversationItem {
	last := types.PrivateMessageItem{}
	if c != nil && c.LastMessage != nil {
		last = privateMessageItemFromProto(c.LastMessage)
	}
	if c == nil {
		return types.PrivateConversationItem{LastMessage: last}
	}
	return types.PrivateConversationItem{
		PeerUserId:        c.GetPeerId(),
		PeerName:          c.GetPeerName(),
		PeerAvatar:        c.GetPeerAvatar(),
		PeerMoeNo:         c.GetPeerMoeNo(),
		PeerDisplayUserId: c.GetPeerDisplayUserId(),
		LastMessage:       last,
		UnreadCount:       int(c.GetUnreadCount()),
	}
}
