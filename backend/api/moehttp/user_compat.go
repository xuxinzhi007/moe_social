package moehttp

import (
	"backend/api/internal/svc"
	huser "backend/api/internal/handler/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeUserCompatRoutes 用户 / 鉴权 / 社交 / VIP（logic 薄转；记忆见 user_memory_compat）。
const PilotNativeUserCompatRoutes = 49

func RegisterUserCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/auth/feishu/authorize-url", wrapNativeHTTP(huser.FeishuAuthorizeURLHandler(svcCtx)))
	r.GET("/api/auth/feishu/callback", wrapNativeHTTP(huser.FeishuOAuthCallbackHandler(svcCtx)))
	r.POST("/api/auth/feishu/login", wrapNativeHTTP(huser.FeishuLoginHandler(svcCtx)))
	r.GET("/api/auth/feishu/public-config", wrapNativeHTTP(huser.FeishuPublicConfigHandler(svcCtx)))
	r.GET("/api/auth/wechat/authorize-url", wrapNativeHTTP(huser.WechatAuthorizeURLHandler(svcCtx)))
	r.GET("/api/auth/wechat/callback", wrapNativeHTTP(huser.WechatOAuthCallbackHandler(svcCtx)))
	r.POST("/api/auth/wechat/login", wrapNativeHTTP(huser.WechatLoginHandler(svcCtx)))
	r.GET("/api/transactions/:transaction_id", wrapNativeHTTP(huser.GetTransactionHandler(svcCtx)))
	r.GET("/api/user/:follower_id/follow/:following_id/check", wrapNativeHTTP(huser.CheckFollowHandler(svcCtx)))
	r.GET("/api/user/:user_id", wrapNativeHTTP(huser.GetUserInfoHandler(svcCtx)))
	r.PUT("/api/user/:user_id", wrapNativeHTTP(huser.UpdateUserInfoHandler(svcCtx)))
	r.DELETE("/api/user/:user_id", wrapNativeHTTP(huser.DeleteUserHandler(svcCtx)))
	r.GET("/api/user/:user_id/detail", wrapNativeHTTP(huser.GetUserHandler(svcCtx)))
	r.GET("/api/user/:user_id/devices", wrapNativeHTTP(huser.ListUserDevicesHandler(svcCtx)))
	r.POST("/api/user/:user_id/devices/sync", wrapNativeHTTP(huser.SyncUserDeviceHandler(svcCtx)))
	r.POST("/api/user/:user_id/follow", wrapNativeHTTP(huser.FollowUserHandler(svcCtx)))
	r.DELETE("/api/user/:user_id/follow", wrapNativeHTTP(huser.UnfollowUserHandler(svcCtx)))
	r.GET("/api/user/:user_id/followers", wrapNativeHTTP(huser.GetFollowersHandler(svcCtx)))
	r.GET("/api/user/:user_id/following", wrapNativeHTTP(huser.GetFollowingsHandler(svcCtx)))
	r.POST("/api/user/:user_id/friend-requests", wrapNativeHTTP(huser.SendFriendRequestHandler(svcCtx)))
	r.POST("/api/user/:user_id/friend-requests/:request_id/accept", wrapNativeHTTP(huser.AcceptFriendRequestHandler(svcCtx)))
	r.POST("/api/user/:user_id/friend-requests/:request_id/reject", wrapNativeHTTP(huser.RejectFriendRequestHandler(svcCtx)))
	r.GET("/api/user/:user_id/friend-requests/incoming", wrapNativeHTTP(huser.ListIncomingFriendRequestsHandler(svcCtx)))
	r.GET("/api/user/:user_id/friend-requests/outgoing", wrapNativeHTTP(huser.ListOutgoingFriendRequestsHandler(svcCtx)))
	r.GET("/api/user/:user_id/friends", wrapNativeHTTP(huser.ListFriendsHandler(svcCtx)))
	r.GET("/api/user/:user_id/friends/status/:other_user_id", wrapNativeHTTP(huser.GetFriendStatusHandler(svcCtx)))
	r.PUT("/api/user/:user_id/password", wrapNativeHTTP(huser.UpdateUserPasswordHandler(svcCtx)))
	r.GET("/api/user/:user_id/transactions", wrapNativeHTTP(huser.GetTransactionsHandler(svcCtx)))
	r.POST("/api/user/:user_id/vip", wrapNativeHTTP(huser.UpdateUserVipHandler(svcCtx)))
	r.GET("/api/user/:user_id/vip", wrapNativeHTTP(huser.GetUserVipStatusHandler(svcCtx)))
	r.GET("/api/user/:user_id/vip/active", wrapNativeHTTP(huser.GetUserActiveVipRecordHandler(svcCtx)))
	r.PUT("/api/user/:user_id/vip/auto-renew", wrapNativeHTTP(huser.UpdateAutoRenewHandler(svcCtx)))
	r.GET("/api/user/:user_id/vip/check", wrapNativeHTTP(huser.CheckUserVipHandler(svcCtx)))
	r.GET("/api/user/:user_id/vip/orders", wrapNativeHTTP(huser.GetVipOrdersHandler(svcCtx)))
	r.POST("/api/user/:user_id/vip/orders", wrapNativeHTTP(huser.CreateVipOrderHandler(svcCtx)))
	r.GET("/api/user/:user_id/vip/records", wrapNativeHTTP(huser.GetVipHistoryHandler(svcCtx)))
	r.POST("/api/user/:user_id/vip/sync", wrapNativeHTTP(huser.SyncUserVipStatusHandler(svcCtx)))
	r.POST("/api/user/:user_id/wallet/recharge", wrapNativeHTTP(huser.RechargeHandler(svcCtx)))
	r.POST("/api/user/check-email", wrapNativeHTTP(huser.CheckUserByEmailHandler(svcCtx)))
	r.POST("/api/user/login", wrapNativeHTTP(huser.LoginHandler(svcCtx)))
	r.POST("/api/user/refresh-token", wrapNativeHTTP(huser.RefreshTokenHandler(svcCtx)))
	r.POST("/api/user/register", wrapNativeHTTP(huser.RegisterHandler(svcCtx)))
	r.POST("/api/user/reset-password", wrapNativeHTTP(huser.ResetPasswordHandler(svcCtx)))
	r.GET("/api/users", wrapNativeHTTP(huser.GetUsersHandler(svcCtx)))
	r.GET("/api/users/count", wrapNativeHTTP(huser.GetUserCountHandler(svcCtx)))
	r.DELETE("/api/user/account", wrapNativeHTTP(huser.DeleteMyAccountHandler(svcCtx)))
	r.PUT("/api/user/feishu/bind", wrapNativeHTTP(huser.BindFeishuHandler(svcCtx)))
	r.DELETE("/api/user/feishu/bind", wrapNativeHTTP(huser.UnbindFeishuHandler(svcCtx)))
	r.POST("/api/user/feishu/test-card", wrapNativeHTTP(huser.SendFeishuTestCardHandler(svcCtx)))
}
