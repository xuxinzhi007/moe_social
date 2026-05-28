package moehttp

import (
	"backend/api/internal/svc"
	hadminpublic "backend/api/internal/handler/admin_public"
	hai "backend/api/internal/handler/ai"
	havatar "backend/api/internal/handler/avatar"
	hchat "backend/api/internal/handler/chat"
	hcommunity "backend/api/internal/handler/community"
	hcontent "backend/api/internal/handler/content"
	hemoji "backend/api/internal/handler/emoji"
	himage "backend/api/internal/handler/image"
	hnotification "backend/api/internal/handler/notification"
	hpost "backend/api/internal/handler/post"
	hprivatemsg "backend/api/internal/handler/privatemsg"
	hvip "backend/api/internal/handler/vip"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeWave2CompatRoutes 波次2：post/community/ai/通知等（logic 薄转）。
const PilotNativeWave2CompatRoutes = 70

// RegisterWave2LogicCompat 非 admin/user 域批量迁出 routes_native_gen。
func RegisterWave2LogicCompat(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	// admin public
	r.POST("/api/admin/bootstrap/account", wrapNativeHTTP(hadminpublic.AdminBootstrapAccountHandler(svc)))
	r.POST("/api/admin/login", wrapNativeHTTP(hadminpublic.AdminLoginHandler(svc)))
	// ai
	r.GET("/api/ai/agents", wrapNativeHTTP(hai.ListAgentsHandler(svc)))
	r.PUT("/api/ai/agents", wrapNativeHTTP(hai.UpsertAgentHandler(svc)))
	r.DELETE("/api/ai/agents", wrapNativeHTTP(hai.DeleteAgentHandler(svc)))
	r.GET("/api/ai/agents/public", wrapNativeHTTP(hai.ListPublicAgentsHandler(svc)))
	r.GET("/api/ai/config", wrapNativeHTTP(hai.GetUserConfigHandler(svc)))
	r.PUT("/api/ai/config", wrapNativeHTTP(hai.UpsertUserConfigHandler(svc)))
	r.GET("/api/ai/lorebooks", wrapNativeHTTP(hai.ListLorebooksHandler(svc)))
	r.PUT("/api/ai/lorebooks", wrapNativeHTTP(hai.UpsertLorebookHandler(svc)))
	r.DELETE("/api/ai/lorebooks", wrapNativeHTTP(hai.DeleteLorebookHandler(svc)))
	r.GET("/api/ai/memory/settings", wrapNativeHTTP(hai.GetAiMemorySettingsHandler(svc)))
	r.PUT("/api/ai/memory/settings", wrapNativeHTTP(hai.PutAiMemorySettingsHandler(svc)))
	r.GET("/api/ai/providers", wrapNativeHTTP(hai.ListProvidersHandler(svc)))
	r.PUT("/api/ai/providers", wrapNativeHTTP(hai.UpsertProviderHandler(svc)))
	r.DELETE("/api/ai/providers", wrapNativeHTTP(hai.DeleteProviderHandler(svc)))
	// avatar
	r.GET("/api/avatar/:user_id", wrapNativeHTTP(havatar.GetUserAvatarHandler(svc)))
	r.PUT("/api/avatar/:user_id", wrapNativeHTTP(havatar.UpdateUserAvatarHandler(svc)))
	r.GET("/api/avatar/outfits", wrapNativeHTTP(havatar.GetAvatarOutfitsHandler(svc)))
	r.GET("/api/avatar/outfits/:outfit_id", wrapNativeHTTP(havatar.GetAvatarOutfitHandler(svc)))
	r.POST("/api/avatar/outfits/:outfit_id/purchase", wrapNativeHTTP(havatar.PurchaseAvatarOutfitHandler(svc)))
	// chat
	r.GET("/api/chat/online", wrapNativeHTTP(hchat.ChatOnlineHandler(svc)))
	r.GET("/api/chat/online/batch", wrapNativeHTTP(hchat.ChatOnlineBatchHandler(svc)))
	r.GET("/ws/chat", wrapNativeHTTP(hchat.ChatWsHandler(svc)))
	r.GET("/ws/presence", wrapNativeHTTP(hchat.PresenceWsHandler(svc)))
	r.GET("/ws/remote", wrapNativeHTTP(hchat.RemoteWsHandler(svc)))
	r.GET("/ws/world", wrapNativeHTTP(hchat.WorldWsHandler(svc)))
	// community
	r.GET("/api/community/groups", wrapNativeHTTP(hcommunity.GetGroupsHandler(svc)))
	r.POST("/api/community/groups", wrapNativeHTTP(hcommunity.CreateGroupHandler(svc)))
	r.GET("/api/community/groups/:group_id", wrapNativeHTTP(hcommunity.GetGroupHandler(svc)))
	r.PUT("/api/community/groups/:group_id", wrapNativeHTTP(hcommunity.UpdateGroupHandler(svc)))
	r.DELETE("/api/community/groups/:group_id", wrapNativeHTTP(hcommunity.DeleteGroupHandler(svc)))
	r.POST("/api/community/groups/:group_id/join", wrapNativeHTTP(hcommunity.JoinGroupHandler(svc)))
	r.POST("/api/community/groups/:group_id/leave", wrapNativeHTTP(hcommunity.LeaveGroupHandler(svc)))
	r.GET("/api/community/groups/:group_id/members", wrapNativeHTTP(hcommunity.GetGroupMembersHandler(svc)))
	r.POST("/api/community/groups/:group_id/posts", wrapNativeHTTP(hcommunity.CreateGroupPostHandler(svc)))
	r.GET("/api/community/groups/:group_id/posts", wrapNativeHTTP(hcommunity.GetGroupPostsHandler(svc)))
	r.GET("/api/user/:user_id/community/groups", wrapNativeHTTP(hcommunity.GetUserGroupsHandler(svc)))
	// content (仅 generate；列表仍走 native)
	r.POST("/api/content/generate", wrapNativeHTTP(hcontent.GenerateContentHandler(svc)))
	// emoji
	r.GET("/api/emoji/packs", wrapNativeHTTP(hemoji.GetEmojiPacksHandler(svc)))
	r.GET("/api/emoji/packs/:pack_id", wrapNativeHTTP(hemoji.GetEmojiPackHandler(svc)))
	r.POST("/api/emoji/packs/:pack_id/favorite", wrapNativeHTTP(hemoji.FavoriteEmojiPackHandler(svc)))
	r.POST("/api/emoji/packs/:pack_id/purchase", wrapNativeHTTP(hemoji.PurchaseEmojiPackHandler(svc)))
	r.GET("/api/user/:user_id/emoji/packs", wrapNativeHTTP(hemoji.GetUserEmojiPacksHandler(svc)))
	// image
	r.GET("/api/images", wrapNativeHTTP(himage.GetImageListHandler(svc)))
	r.DELETE("/api/images/:filename", wrapNativeHTTP(himage.DeleteImageHandler(svc)))
	r.GET("/api/images/:filename", wrapNativeHTTP(himage.GetImageHandler(svc)))
	r.POST("/api/upload", wrapNativeHTTP(himage.UploadImageHandler(svc)))
	// notification
	r.POST("/api/notification/broadcast", wrapNativeHTTP(hnotification.BroadcastNotificationHandler(svc)))
	r.POST("/api/notification/send", wrapNativeHTTP(hnotification.SendNotificationHandler(svc)))
	r.POST("/api/notification/send-batch", wrapNativeHTTP(hnotification.SendBatchNotificationHandler(svc)))
	r.GET("/api/notifications", wrapNativeHTTP(hnotification.GetNotificationsHandler(svc)))
	r.POST("/api/notifications/:id/read", wrapNativeHTTP(hnotification.ReadNotificationHandler(svc)))
	r.POST("/api/notifications/read-all", wrapNativeHTTP(hnotification.ReadAllNotificationsHandler(svc)))
	r.GET("/api/notifications/unread", wrapNativeHTTP(hnotification.GetUnreadCountHandler(svc)))
	// post
	r.GET("/api/posts", wrapNativeHTTP(hpost.GetPostsHandler(svc)))
	r.POST("/api/posts", wrapNativeHTTP(hpost.CreatePostHandler(svc)))
	r.GET("/api/posts/:post_id", wrapNativeHTTP(hpost.GetPostHandler(svc)))
	r.PUT("/api/posts/:post_id", wrapNativeHTTP(hpost.UpdatePostHandler(svc)))
	r.DELETE("/api/posts/:post_id", wrapNativeHTTP(hpost.DeletePostHandler(svc)))
	r.GET("/api/posts/:post_id/comments", wrapNativeHTTP(hpost.GetPostCommentsHandler(svc)))
	r.POST("/api/posts/:post_id/like", wrapNativeHTTP(hpost.LikePostHandler(svc)))
	r.POST("/api/posts/:post_id/report", wrapNativeHTTP(hpost.ReportPostHandler(svc)))
	r.GET("/api/posts/search", wrapNativeHTTP(hpost.SearchPostsHandler(svc)))
	// private message
	r.POST("/api/private-messages", wrapNativeHTTP(hprivatemsg.SendPrivateMessageHandler(svc)))
	r.GET("/api/private-messages", wrapNativeHTTP(hprivatemsg.ListPrivateMessagesHandler(svc)))
	r.GET("/api/private-messages/conversations", wrapNativeHTTP(hprivatemsg.ListPrivateConversationsHandler(svc)))
	// vip (public plans)
	r.GET("/api/vip/plans", wrapNativeHTTP(hvip.GetVipPlansHandler(svc)))
	r.POST("/api/vip/plans", wrapNativeHTTP(hvip.CreateVipPlanHandler(svc)))
	r.GET("/api/vip/plans/:plan_id", wrapNativeHTTP(hvip.GetVipPlanHandler(svc)))
}
