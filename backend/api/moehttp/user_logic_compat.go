package moehttp

import (
	"backend/api/internal/svc"
	huser "backend/api/internal/handler/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeUserCompatRoutes 用户域 Kratos HTTP（波次2：logic 薄转，待二期直挂 user.App）。
const PilotNativeUserCompatRoutes = 57

// RegisterUserLogicCompat 用户 / 鉴权 / 社交 / VIP 子路径 HTTP。
func RegisterUserLogicCompat(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/auth/feishu/authorize-url", wrapNativeHTTP(huser.FeishuAuthorizeURLHandler(svc)))
	r.GET("/api/auth/feishu/callback", wrapNativeHTTP(huser.FeishuOAuthCallbackHandler(svc)))
	r.POST("/api/auth/feishu/login", wrapNativeHTTP(huser.FeishuLoginHandler(svc)))
	r.GET("/api/auth/feishu/public-config", wrapNativeHTTP(huser.FeishuPublicConfigHandler(svc)))
	r.GET("/api/auth/wechat/authorize-url", wrapNativeHTTP(huser.WechatAuthorizeURLHandler(svc)))
	r.GET("/api/auth/wechat/callback", wrapNativeHTTP(huser.WechatOAuthCallbackHandler(svc)))
	r.POST("/api/auth/wechat/login", wrapNativeHTTP(huser.WechatLoginHandler(svc)))
	r.GET("/api/transactions/:transaction_id", wrapNativeHTTP(huser.GetTransactionHandler(svc)))
	r.GET("/api/user/:follower_id/follow/:following_id/check", wrapNativeHTTP(huser.CheckFollowHandler(svc)))
	r.GET("/api/user/:user_id", wrapNativeHTTP(huser.GetUserInfoHandler(svc)))
	r.PUT("/api/user/:user_id", wrapNativeHTTP(huser.UpdateUserInfoHandler(svc)))
	r.DELETE("/api/user/:user_id", wrapNativeHTTP(huser.DeleteUserHandler(svc)))
	r.GET("/api/user/:user_id/detail", wrapNativeHTTP(huser.GetUserHandler(svc)))
	r.GET("/api/user/:user_id/devices", wrapNativeHTTP(huser.ListUserDevicesHandler(svc)))
	r.POST("/api/user/:user_id/devices/sync", wrapNativeHTTP(huser.SyncUserDeviceHandler(svc)))
	r.POST("/api/user/:user_id/follow", wrapNativeHTTP(huser.FollowUserHandler(svc)))
	r.DELETE("/api/user/:user_id/follow", wrapNativeHTTP(huser.UnfollowUserHandler(svc)))
	r.GET("/api/user/:user_id/followers", wrapNativeHTTP(huser.GetFollowersHandler(svc)))
	r.GET("/api/user/:user_id/following", wrapNativeHTTP(huser.GetFollowingsHandler(svc)))
	r.POST("/api/user/:user_id/friend-requests", wrapNativeHTTP(huser.SendFriendRequestHandler(svc)))
	r.POST("/api/user/:user_id/friend-requests/:request_id/accept", wrapNativeHTTP(huser.AcceptFriendRequestHandler(svc)))
	r.POST("/api/user/:user_id/friend-requests/:request_id/reject", wrapNativeHTTP(huser.RejectFriendRequestHandler(svc)))
	r.GET("/api/user/:user_id/friend-requests/incoming", wrapNativeHTTP(huser.ListIncomingFriendRequestsHandler(svc)))
	r.GET("/api/user/:user_id/friend-requests/outgoing", wrapNativeHTTP(huser.ListOutgoingFriendRequestsHandler(svc)))
	r.GET("/api/user/:user_id/friends", wrapNativeHTTP(huser.ListFriendsHandler(svc)))
	r.GET("/api/user/:user_id/friends/status/:other_user_id", wrapNativeHTTP(huser.GetFriendStatusHandler(svc)))
	r.POST("/api/user/:user_id/memories", wrapNativeHTTP(huser.UpsertUserMemoryHandler(svc)))
	r.GET("/api/user/:user_id/memories", wrapNativeHTTP(huser.GetUserMemoriesHandler(svc)))
	r.DELETE("/api/user/:user_id/memories", wrapNativeHTTP(huser.DeleteUserMemoryHandler(svc)))
	r.GET("/api/user/:user_id/memories/display", wrapNativeHTTP(huser.GetUserMemoriesDisplayHandler(svc)))
	r.POST("/api/user/:user_id/memories/feedback", wrapNativeHTTP(huser.SubmitUserMemoryFeedbackHandler(svc)))
	r.GET("/api/user/:user_id/memories/profiles", wrapNativeHTTP(huser.GetUserMemoryProfilesHandler(svc)))
	r.POST("/api/user/:user_id/memories/reindex", wrapNativeHTTP(huser.RebuildUserMemoryEmbeddingsHandler(svc)))
	r.GET("/api/user/:user_id/memories/search", wrapNativeHTTP(huser.SearchUserMemoriesHandler(svc)))
	r.PUT("/api/user/:user_id/password", wrapNativeHTTP(huser.UpdateUserPasswordHandler(svc)))
	r.GET("/api/user/:user_id/transactions", wrapNativeHTTP(huser.GetTransactionsHandler(svc)))
	r.POST("/api/user/:user_id/vip", wrapNativeHTTP(huser.UpdateUserVipHandler(svc)))
	r.GET("/api/user/:user_id/vip", wrapNativeHTTP(huser.GetUserVipStatusHandler(svc)))
	r.GET("/api/user/:user_id/vip/active", wrapNativeHTTP(huser.GetUserActiveVipRecordHandler(svc)))
	r.PUT("/api/user/:user_id/vip/auto-renew", wrapNativeHTTP(huser.UpdateAutoRenewHandler(svc)))
	r.GET("/api/user/:user_id/vip/check", wrapNativeHTTP(huser.CheckUserVipHandler(svc)))
	r.GET("/api/user/:user_id/vip/orders", wrapNativeHTTP(huser.GetVipOrdersHandler(svc)))
	r.POST("/api/user/:user_id/vip/orders", wrapNativeHTTP(huser.CreateVipOrderHandler(svc)))
	r.GET("/api/user/:user_id/vip/records", wrapNativeHTTP(huser.GetVipHistoryHandler(svc)))
	r.POST("/api/user/:user_id/vip/sync", wrapNativeHTTP(huser.SyncUserVipStatusHandler(svc)))
	r.POST("/api/user/:user_id/wallet/recharge", wrapNativeHTTP(huser.RechargeHandler(svc)))
	r.POST("/api/user/check-email", wrapNativeHTTP(huser.CheckUserByEmailHandler(svc)))
	r.POST("/api/user/login", wrapNativeHTTP(huser.LoginHandler(svc)))
	r.POST("/api/user/refresh-token", wrapNativeHTTP(huser.RefreshTokenHandler(svc)))
	r.POST("/api/user/register", wrapNativeHTTP(huser.RegisterHandler(svc)))
	r.POST("/api/user/reset-password", wrapNativeHTTP(huser.ResetPasswordHandler(svc)))
	r.GET("/api/users", wrapNativeHTTP(huser.GetUsersHandler(svc)))
	r.GET("/api/users/count", wrapNativeHTTP(huser.GetUserCountHandler(svc)))
	r.DELETE("/api/user/account", wrapNativeHTTP(huser.DeleteMyAccountHandler(svc)))
	r.PUT("/api/user/feishu/bind", wrapNativeHTTP(huser.BindFeishuHandler(svc)))
	r.DELETE("/api/user/feishu/bind", wrapNativeHTTP(huser.UnbindFeishuHandler(svc)))
	r.POST("/api/user/feishu/test-card", wrapNativeHTTP(huser.SendFeishuTestCardHandler(svc)))
}
