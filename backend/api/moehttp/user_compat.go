package moehttp

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	userapp "backend/internal/service/user"
	"backend/rpc/pb/moe"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeUserCompatRoutes 用户 / 鉴权 / 社交 / VIP（UserApp tier-A）。
const PilotNativeUserCompatRoutes = 49

func RegisterUserCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	app := svcCtx.UserApp
	r := srv.Route("/")

	r.GET("/api/auth/feishu/callback", userFeishuOAuthCallback())
	r.GET("/api/auth/wechat/callback", userWechatOAuthCallback())
	r.POST("/api/user/refresh-token", userRefreshToken())

	if app == nil {
		return
	}

	r.GET("/api/auth/feishu/authorize-url", feishuAuthorizeURL(app))
	r.POST("/api/auth/feishu/login", feishuLogin(app))
	r.GET("/api/auth/feishu/public-config", feishuPublicConfig())
	r.GET("/api/auth/wechat/authorize-url", wechatAuthorizeURL(app))
	r.POST("/api/auth/wechat/login", wechatLogin(app))
	r.GET("/api/transactions/:transaction_id", getTransaction(app))
	r.GET("/api/user/:follower_id/follow/:following_id/check", checkFollow(app))
	r.GET("/api/user/:user_id", getUserInfo(app))
	r.PUT("/api/user/:user_id", updateUserInfo(app))
	r.DELETE("/api/user/:user_id", deleteUser(app))
	r.GET("/api/user/:user_id/detail", getUser(app))
	r.GET("/api/user/:user_id/devices", listUserDevices(app))
	r.POST("/api/user/:user_id/devices/sync", syncUserDevice(app))
	r.POST("/api/user/:user_id/follow", followUser(app))
	r.DELETE("/api/user/:user_id/follow", unfollowUser(app))
	r.GET("/api/user/:user_id/followers", getFollowers(app))
	r.GET("/api/user/:user_id/following", getFollowings(app))
	r.POST("/api/user/:user_id/friend-requests", sendFriendRequest(app))
	r.POST("/api/user/:user_id/friend-requests/:request_id/accept", acceptFriendRequest(app))
	r.POST("/api/user/:user_id/friend-requests/:request_id/reject", rejectFriendRequest(app))
	r.GET("/api/user/:user_id/friend-requests/incoming", listIncomingFriendRequests(app))
	r.GET("/api/user/:user_id/friend-requests/outgoing", listOutgoingFriendRequests(app))
	r.GET("/api/user/:user_id/friends", listFriends(app))
	r.GET("/api/user/:user_id/friends/status/:other_user_id", getFriendStatus(app))
	r.PUT("/api/user/:user_id/password", updateUserPassword(app))
	r.GET("/api/user/:user_id/transactions", getTransactions(app))
	r.POST("/api/user/:user_id/vip", updateUserVip(app))
	r.GET("/api/user/:user_id/vip", getUserVipStatus(app))
	r.GET("/api/user/:user_id/vip/active", getUserActiveVipRecord(app))
	r.PUT("/api/user/:user_id/vip/auto-renew", updateAutoRenew(app))
	r.GET("/api/user/:user_id/vip/check", checkUserVip(app))
	r.GET("/api/user/:user_id/vip/orders", getVipOrders(app))
	r.POST("/api/user/:user_id/vip/orders", createVipOrder(app))
	r.GET("/api/user/:user_id/vip/records", getVipHistory(app))
	r.POST("/api/user/:user_id/vip/sync", syncUserVipStatus(app))
	r.POST("/api/user/:user_id/wallet/recharge", recharge(app))
	r.POST("/api/user/check-email", checkUserByEmail(app))
	r.POST("/api/user/login", login(app))
	r.POST("/api/user/register", register(app))
	r.POST("/api/user/reset-password", resetPassword(app))
	r.GET("/api/users", getUsers(app))
	r.GET("/api/users/count", getUserCount(app))
	r.DELETE("/api/user/account", deleteMyAccount(app))
	r.PUT("/api/user/feishu/bind", bindFeishu(app))
	r.DELETE("/api/user/feishu/bind", unbindFeishu(app))
	r.POST("/api/user/feishu/test-card", sendFeishuTestCard(app))
}

func feishuAuthorizeURL(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FeishuAuthorizeURLReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FeishuAuthorizeURLResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.FeishuAuthorizeURL(ctx, &moe.FeishuAuthorizeURLReq{
			State: strings.TrimSpace(req.State),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FeishuAuthorizeURLResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.FeishuAuthorizeURLResp{
			BaseResp: common.HandleRPCError(nil, ""),
			Data:     types.FeishuAuthorizeURLData{AuthorizeURL: rpcResp.GetAuthorizeUrl()},
		})
	}
}

func feishuLogin(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FeishuLoginReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FeishuLoginResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.FeishuLogin(ctx, &moe.FeishuLoginReq{Code: strings.TrimSpace(req.Code)})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FeishuLoginResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.FeishuLoginResp{BaseResp: common.HandleRPCError(nil, "登录成功")}
		if rpcResp.GetUser() != nil {
			resp.Data = types.FeishuLoginData{
				User: userFromRPC(rpcResp.GetUser()), Token: rpcResp.GetToken(), IsNewUser: rpcResp.GetIsNewUser(),
			}
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func feishuPublicConfig() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		cfg := utils.GetFeishuPublicConfig()
		return ctx.JSON(http.StatusOK, types.FeishuPublicConfigResp{
			BaseResp: common.HandleRPCError(nil, ""),
			Data: types.FeishuPublicConfigData{
				Enabled: cfg.Enabled, EnterpriseInviteURL: cfg.EnterpriseInviteURL, Notice: cfg.Notice,
			},
		})
	}
}

func wechatAuthorizeURL(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.WechatAuthorizeURLReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.WechatAuthorizeURLResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.WechatAuthorizeURL(ctx, &moe.WechatAuthorizeURLReq{
			State: strings.TrimSpace(req.State), Flow: strings.TrimSpace(req.Flow),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.WechatAuthorizeURLResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.WechatAuthorizeURLResp{
			BaseResp: common.HandleRPCError(nil, ""),
			Data:     types.WechatAuthorizeURLData{AuthorizeURL: rpcResp.GetAuthorizeUrl()},
		})
	}
}

func wechatLogin(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.WechatLoginReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.WechatLoginResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.WechatLogin(ctx, &moe.WechatLoginReq{
			Code: strings.TrimSpace(req.Code), Flow: strings.TrimSpace(req.Flow),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.WechatLoginResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.WechatLoginResp{BaseResp: common.HandleRPCError(nil, "登录成功")}
		if rpcResp.GetUser() != nil {
			resp.Data = types.WechatLoginData{
				User: userFromRPC(rpcResp.GetUser()), Token: rpcResp.GetToken(), IsNewUser: rpcResp.GetIsNewUser(),
			}
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func login(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LoginReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.LoginResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.Login(ctx, &moe.LoginReq{
			Username: req.Username, Password: req.Password, Email: req.Email,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.LoginResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		resp := types.LoginResp{BaseResp: common.HandleRPCError(nil, "登录成功")}
		if rpcResp.User != nil {
			resp.Data = types.LoginData{User: userFromRPC(rpcResp.User), Token: rpcResp.Token}
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func register(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.RegisterReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.RegisterResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.Register(ctx, &moe.RegisterReq{
			Username: req.Username, Password: req.Password, Email: req.Email,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.RegisterResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		resp := types.RegisterResp{BaseResp: common.HandleRPCError(nil, "注册成功")}
		if rpcResp.User != nil {
			resp.Data = types.RegisterData{User: userFromRPC(rpcResp.User), Token: rpcResp.Token}
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func resetPassword(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ResetPasswordReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ResetPasswordResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		if req.Email == "" {
			return ctx.JSON(http.StatusOK, types.ResetPasswordResp{
				BaseResp: common.HandleError(errEmptyEmail()),
			})
		}
		if req.NewPassword == "" {
			return ctx.JSON(http.StatusOK, types.ResetPasswordResp{
				BaseResp: common.HandleError(errEmptyPassword()),
			})
		}
		_, err := app.ResetPassword(ctx, &moe.ResetPasswordReq{Email: req.Email, NewPassword: req.NewPassword})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ResetPasswordResp{
				BaseResp: common.HandleRPCError(err, "重置密码失败"),
			})
		}
		return ctx.JSON(http.StatusOK, types.ResetPasswordResp{
			BaseResp: common.HandleRPCError(nil, "重置密码成功"),
		})
	}
}

func checkUserByEmail(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserByEmailReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserByEmailResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		if req.Email == "" {
			return ctx.JSON(http.StatusOK, types.GetUserByEmailResp{
				BaseResp: common.HandleError(errEmptyEmail()),
			})
		}
		rpcResp, err := app.GetUserByEmail(ctx, &moe.GetUserByEmailReq{Email: req.Email})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserByEmailResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetUserByEmailResp{
			BaseResp: common.HandleRPCError(nil, "查询成功"),
			Data:     userFromRPC(rpcResp.User),
		})
	}
}

func getUsers(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUsersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUsersResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUsers(ctx, &moe.GetUsersReq{Page: int32(req.Page), PageSize: int32(req.PageSize)})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUsersResp{
				BaseResp: common.HandleRPCError(err, ""), Data: nil, Total: 0,
			})
		}
		users := make([]types.User, 0, len(rpcResp.Users))
		for _, u := range rpcResp.Users {
			users = append(users, userFromRPC(u))
		}
		return ctx.JSON(http.StatusOK, types.GetUsersResp{
			BaseResp: common.HandleRPCError(nil, "获取用户列表成功"), Data: users, Total: int(rpcResp.Total),
		})
	}
}

func getUserCount(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rpcResp, err := app.GetUserCount(ctx, &moe.GetUserCountReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserCountResp{
				BaseResp: common.HandleRPCError(err, ""), Data: 0,
			})
		}
		return ctx.JSON(http.StatusOK, types.GetUserCountResp{
			BaseResp: common.HandleRPCError(nil, "获取用户数量成功"), Data: int(rpcResp.Count),
		})
	}
}

func getUserInfo(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserInfoReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserInfoResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserInfo(ctx, &moe.GetUserInfoReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserInfoResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetUserInfoResp{
			BaseResp: common.HandleRPCError(nil, "获取用户信息成功"), Data: userFromRPC(rpcResp.User),
		})
	}
}

func getUser(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUser(ctx, &moe.GetUserReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetUserResp{
			BaseResp: common.HandleRPCError(nil, "获取用户信息成功"), Data: userFromRPC(rpcResp.User),
		})
	}
}

func updateUserInfo(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdateUserInfoReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdateUserInfoResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpdateUserInfo(ctx, &moe.UpdateUserInfoReq{
			UserId: req.UserId, Username: req.Username, Email: req.Email, Avatar: req.Avatar,
			Signature: req.Signature, Gender: req.Gender, Birthday: req.Birthday,
			Inventory: req.Inventory, EquippedFrameId: req.EquippedFrameId,
			ClearEquippedFrame: req.ClearEquippedFrame, MessageRetention: req.MessageRetention,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpdateUserInfoResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UpdateUserInfoResp{
			BaseResp: common.HandleRPCError(nil, "更新用户信息成功"), Data: userFromRPC(rpcResp.User),
		})
	}
}

func updateUserPassword(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdateUserPasswordReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdateUserPasswordResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.UpdateUserPassword(ctx, &moe.UpdateUserPasswordReq{
			UserId: req.UserId, OldPassword: req.OldPassword, NewPassword: req.NewPassword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpdateUserPasswordResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UpdateUserPasswordResp{
			BaseResp: common.HandleRPCError(nil, "更新密码成功"),
		})
	}
}

func deleteUser(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.DeleteUserReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.DeleteUserResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.DeleteUser(ctx, &moe.DeleteUserReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.DeleteUserResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.DeleteUserResp{
			BaseResp: common.HandleRPCError(nil, "删除用户成功"),
		})
	}
}

func deleteMyAccount(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.DeleteUserResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		_, err = app.DeleteUser(ctx, &moe.DeleteUserReq{UserId: userID})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.DeleteUserResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.DeleteUserResp{
			BaseResp: common.HandleRPCError(nil, "账号已注销"),
		})
	}
}

func bindFeishu(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.BindFeishuReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BindFeishuResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		userID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.BindFeishuResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		rpcResp, err := app.BindFeishu(ctx, &moe.BindFeishuReq{UserId: userID, FeishuEmail: req.FeishuEmail})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.BindFeishuResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.BindFeishuResp{
			BaseResp: common.HandleRPCError(nil, "飞书绑定成功"), Data: userFromRPC(rpcResp.User),
		})
	}
}

func unbindFeishu(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.UnbindFeishuResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		rpcResp, err := app.UnbindFeishu(ctx, &moe.UnbindFeishuReq{UserId: userID})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UnbindFeishuResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UnbindFeishuResp{
			BaseResp: common.HandleRPCError(nil, "已解除飞书绑定"), Data: userFromRPC(rpcResp.User),
		})
	}
}

func sendFeishuTestCard(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := jwtUserIDString(ctx)
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.SendFeishuTestCardResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		_, err = app.SendFeishuTestCard(ctx, &moe.SendFeishuTestCardReq{UserId: userID})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SendFeishuTestCardResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.SendFeishuTestCardResp{
			BaseResp: common.HandleRPCError(nil, "测试卡片已发送，请在飞书客户端查看"),
		})
	}
}

func followUser(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FollowUserReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FollowUserResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.Follow(ctx, &moe.FollowUserReq{UserId: req.UserId, FollowingId: req.FollowingId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FollowUserResp{
				BaseResp: common.HandleUserGWError(err, ""), Data: false,
			})
		}
		return ctx.JSON(http.StatusOK, types.FollowUserResp{BaseResp: common.HandleError(nil), Data: rpcResp.Success})
	}
}

func unfollowUser(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UnfollowUserReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FollowUserResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.Unfollow(ctx, &moe.UnfollowUserReq{UserId: req.UserId, FollowingId: req.FollowingId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FollowUserResp{
				BaseResp: common.HandleUserGWError(err, ""), Data: false,
			})
		}
		return ctx.JSON(http.StatusOK, types.FollowUserResp{BaseResp: common.HandleError(nil), Data: rpcResp.Success})
	}
}

func checkFollow(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CheckFollowReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CheckFollowResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CheckFollow(ctx, &moe.CheckFollowReq{
			FollowerId: req.FollowerId, FollowingId: req.FollowingId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CheckFollowResp{
				BaseResp: common.HandleUserGWError(err, ""), Data: false,
			})
		}
		return ctx.JSON(http.StatusOK, types.CheckFollowResp{BaseResp: common.HandleError(nil), Data: rpcResp.IsFollowing})
	}
}

func getFollowers(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetFollowersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetFollowersResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetFollowers(ctx, &moe.GetFollowersReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetFollowersResp{
				BaseResp: common.HandleUserGWError(err, ""), Data: nil, Total: 0,
			})
		}
		users := make([]types.User, 0, len(rpcResp.Users))
		for _, u := range rpcResp.Users {
			users = append(users, userFromRPC(u))
		}
		return ctx.JSON(http.StatusOK, types.GetFollowersResp{
			BaseResp: common.HandleError(nil), Data: users, Total: int(rpcResp.Total),
		})
	}
}

func getFollowings(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetFollowingsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetFollowingsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetFollowings(ctx, &moe.GetFollowingsReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetFollowingsResp{
				BaseResp: common.HandleUserGWError(err, ""), Data: nil, Total: 0,
			})
		}
		users := make([]types.User, 0, len(rpcResp.Users))
		for _, u := range rpcResp.Users {
			users = append(users, userFromRPC(u))
		}
		return ctx.JSON(http.StatusOK, types.GetFollowingsResp{
			BaseResp: common.HandleError(nil), Data: users, Total: int(rpcResp.Total),
		})
	}
}

func sendFriendRequest(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SendFriendRequestReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SendFriendRequestResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		me, err := bearerUserID(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SendFriendRequestResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		pathUID, err := parsePathUint(req.UserId)
		if err != nil || pathUID != me {
			return ctx.JSON(http.StatusOK, types.SendFriendRequestResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
		}
		rpcResp, err := app.SendFriendRequest(ctx, &moe.SendFriendRequestReq{
			ActorUserId: actorString(me), ToUserId: strings.TrimSpace(req.ToUserId), ToMoeNo: strings.TrimSpace(req.ToMoeNo),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SendFriendRequestResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.SendFriendRequestResp{
			BaseResp: common.HandleRPCError(nil, "好友申请已发送"), Data: friendViewFromRPC(rpcResp.Data),
		})
	}
}

func listIncomingFriendRequests(app *userapp.AppService) func(khttp.Context) error {
	return friendRequestList(app, true)
}

func listOutgoingFriendRequests(app *userapp.AppService) func(khttp.Context) error {
	return friendRequestList(app, false)
}

func friendRequestList(app *userapp.AppService, incoming bool) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FriendUserPathReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ListFriendRequestsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		me, err := bearerUserID(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListFriendRequestsResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		pathUID, err := parsePathUint(req.UserId)
		if err != nil || pathUID != me {
			return ctx.JSON(http.StatusOK, types.ListFriendRequestsResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
		}
		var data []*moe.FriendRequestView
		if incoming {
			rpcResp, rpcErr := app.ListIncomingFriendRequests(ctx, &moe.ListIncomingFriendRequestsReq{ActorUserId: actorString(me)})
			if rpcErr != nil {
				return ctx.JSON(http.StatusOK, types.ListFriendRequestsResp{BaseResp: common.HandleUserGWError(rpcErr, "")})
			}
			data = rpcResp.Data
		} else {
			rpcResp, rpcErr := app.ListOutgoingFriendRequests(ctx, &moe.ListOutgoingFriendRequestsReq{ActorUserId: actorString(me)})
			if rpcErr != nil {
				return ctx.JSON(http.StatusOK, types.ListFriendRequestsResp{BaseResp: common.HandleUserGWError(rpcErr, "")})
			}
			data = rpcResp.Data
		}
		out := make([]types.FriendRequestView, 0, len(data))
		for _, v := range data {
			out = append(out, friendViewFromRPC(v))
		}
		return ctx.JSON(http.StatusOK, types.ListFriendRequestsResp{
			BaseResp: common.HandleRPCError(nil, "ok"), Data: out,
		})
	}
}

func acceptFriendRequest(app *userapp.AppService) func(khttp.Context) error {
	return friendRequestAction(app, true)
}

func rejectFriendRequest(app *userapp.AppService) func(khttp.Context) error {
	return friendRequestAction(app, false)
}

func friendRequestAction(app *userapp.AppService, accept bool) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FriendRequestActionReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FriendRequestActionResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		me, err := bearerUserID(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FriendRequestActionResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		pathUID, err := parsePathUint(req.UserId)
		if err != nil || pathUID != me {
			return ctx.JSON(http.StatusOK, types.FriendRequestActionResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
		}
		if accept {
			_, err = app.AcceptFriendRequest(ctx, &moe.AcceptFriendRequestReq{
				ActorUserId: actorString(me), RequestId: req.RequestId,
			})
			if err != nil {
				return ctx.JSON(http.StatusOK, types.FriendRequestActionResp{BaseResp: common.HandleUserGWError(err, "")})
			}
			return ctx.JSON(http.StatusOK, types.FriendRequestActionResp{
				BaseResp: common.HandleRPCError(nil, "已同意好友申请"), Data: true,
			})
		}
		_, err = app.RejectFriendRequest(ctx, &moe.RejectFriendRequestReq{
			ActorUserId: actorString(me), RequestId: req.RequestId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FriendRequestActionResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.FriendRequestActionResp{
			BaseResp: common.HandleRPCError(nil, "已拒绝"), Data: true,
		})
	}
}

func listFriends(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FriendUserPathReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ListFriendsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		me, err := bearerUserID(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListFriendsResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		pathUID, err := parsePathUint(req.UserId)
		if err != nil || pathUID != me {
			return ctx.JSON(http.StatusOK, types.ListFriendsResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
		}
		rpcResp, err := app.ListFriends(ctx, &moe.ListFriendsReq{ActorUserId: actorString(me)})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListFriendsResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		out := make([]types.User, 0, len(rpcResp.Users))
		for _, u := range rpcResp.Users {
			out = append(out, userFromRPC(u))
		}
		return ctx.JSON(http.StatusOK, types.ListFriendsResp{
			BaseResp: common.HandleRPCError(nil, "ok"), Data: out,
		})
	}
}

func getFriendStatus(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FriendStatusPathReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FriendStatusResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		me, err := bearerUserID(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FriendStatusResp{
				BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false},
			})
		}
		pathUID, err := parsePathUint(req.UserId)
		if err != nil || pathUID != me {
			return ctx.JSON(http.StatusOK, types.FriendStatusResp{
				BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false},
			})
		}
		rpcResp, err := app.GetFriendRelation(ctx, &moe.GetFriendRelationReq{
			ActorUserId: actorString(me), OtherUserId: strings.TrimSpace(req.OtherUserId),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.FriendStatusResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.FriendStatusResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.FriendRelationData{Relation: rpcResp.Relation},
		})
	}
}

func listUserDevices(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ListUserDevicesReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ListUserDevicesResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.ListUserDevices(ctx, &moe.ListUserDevicesReq{
			UserId: req.UserId, Limit: int32(req.Limit), Offset: int32(req.Offset),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListUserDevicesResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.UserDeviceRecord, 0, len(rpcResp.Devices))
		for _, d := range rpcResp.Devices {
			items = append(items, userDeviceFromRPC(d))
		}
		return ctx.JSON(http.StatusOK, types.ListUserDevicesResp{
			BaseResp: common.HandleRPCError(nil, "查询设备列表成功"),
			Data: items, Total: rpcResp.Total, Limit: int(rpcResp.Limit), Offset: int(rpcResp.Offset), HasMore: rpcResp.HasMore,
		})
	}
}

func syncUserDevice(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SyncUserDeviceReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SyncUserDeviceResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.SyncUserDevice(ctx, &moe.SyncUserDeviceReq{
			UserId: req.UserId, DeviceId: req.DeviceId, Platform: req.Platform,
			OsVersion: req.OSVersion, AppVersion: req.AppVersion, DeviceName: req.DeviceName,
			LastSeen: req.LastSeen, PayloadJson: req.PayloadJSON,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SyncUserDeviceResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.SyncUserDeviceResp{
			BaseResp: common.HandleRPCError(nil, "同步设备信息成功"), Data: userDeviceFromRPC(rpcResp.Device),
		})
	}
}

func getTransactions(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetTransactionsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetTransactionsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetTransactions(ctx, &moe.GetTransactionsReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return err
		}
		transactions := make([]types.Transaction, 0, len(rpcResp.Transactions))
		for _, t := range rpcResp.Transactions {
			transactions = append(transactions, transactionFromRPC(t))
		}
		return ctx.JSON(http.StatusOK, types.GetTransactionsResp{
			BaseResp: types.BaseResp{Code: 200, Message: "获取交易记录成功", Success: true},
			Data: transactions, Total: int(rpcResp.Total),
		})
	}
}

func getTransaction(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetTransactionReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetTransactionResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetTransaction(ctx, &moe.GetTransactionReq{Id: req.TransactionId})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.GetTransactionResp{
			BaseResp: types.BaseResp{Code: 200, Message: "获取交易详情成功", Success: true},
			Data:     transactionFromRPC(rpcResp.Transaction),
		})
	}
}

func recharge(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.RechargeReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.RechargeResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.Recharge(ctx, &moe.RechargeReq{
			UserId: req.UserId, Amount: float32(req.Amount), Description: req.Description,
		})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.RechargeResp{
			BaseResp: types.BaseResp{Code: 200, Message: "充值成功", Success: true},
			Data: types.Transaction{
				UserId: req.UserId, Type: "recharge", Amount: req.Amount,
				Description: req.Description, Status: "success",
			},
		})
	}
}

func getUserVipStatus(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserActiveVipRecordReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserVipStatusResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserVipStatus(ctx, &moe.GetUserVipStatusReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserVipStatusResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetUserVipStatusResp{
			BaseResp: common.HandleRPCError(nil, "获取用户VIP状态成功"),
			Data: types.UserVipStatusData{
				IsVip: rpcResp.IsVip, ExpiresAt: rpcResp.ExpiresAt, AutoRenew: rpcResp.AutoRenew,
			},
		})
	}
}

func checkUserVip(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CheckUserVipReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CheckUserVipResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CheckUserVip(ctx, &moe.CheckUserVipReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CheckUserVipResp{
				BaseResp: common.HandleUserGWError(err, ""), Data: false,
			})
		}
		return ctx.JSON(http.StatusOK, types.CheckUserVipResp{
			BaseResp: common.HandleRPCError(nil, "检查用户VIP状态成功"), Data: rpcResp.IsVip,
		})
	}
}

func updateUserVip(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdateUserVipReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdateUserVipResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpdateUserVip(ctx, &moe.UpdateUserVipReq{
			UserId: req.UserId, IsVip: req.IsVip, VipExpires: req.VipExpires,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpdateUserVipResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UpdateUserVipResp{
			BaseResp: common.HandleRPCError(nil, "更新用户VIP状态成功"), Data: userFromRPC(rpcResp.User),
		})
	}
}

func syncUserVipStatus(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SyncUserVipStatusReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SyncUserVipStatusResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.SyncUserVipStatus(ctx, &moe.SyncUserVipStatusReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SyncUserVipStatusResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.SyncUserVipStatusResp{
			BaseResp: common.HandleRPCError(nil, "同步用户VIP状态成功"),
			Data:     types.SyncUserVipStatusData{IsVip: rpcResp.IsVip, ExpiresAt: rpcResp.ExpiresAt},
		})
	}
}

func updateAutoRenew(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdateAutoRenewReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return err
		}
		_, err := app.UpdateAutoRenew(ctx, &moe.UpdateAutoRenewReq{UserId: req.UserId, AutoRenew: req.AutoRenew})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.EmptyResp{})
	}
}

func getUserActiveVipRecord(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserActiveVipRecordReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserActiveVipRecordResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserActiveVipRecord(ctx, &moe.GetUserActiveVipRecordReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserActiveVipRecordResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetUserActiveVipRecordResp{
			BaseResp: common.HandleRPCError(nil, "获取用户活跃VIP记录成功"),
			Data:     vipRecordFromRPC(rpcResp.Record),
		})
	}
}

func getVipOrders(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetVipOrdersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetVipOrdersResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetVipOrders(ctx, &moe.GetVipOrdersReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetVipOrdersResp{
				BaseResp: common.HandleRPCError(err, ""), Data: nil, Total: 0,
			})
		}
		orders := make([]types.VipOrder, 0, len(rpcResp.Orders))
		for _, o := range rpcResp.Orders {
			orders = append(orders, vipOrderFromRPC(o))
		}
		return ctx.JSON(http.StatusOK, types.GetVipOrdersResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP订单列表成功"), Data: orders, Total: int(rpcResp.Total),
		})
	}
}

func createVipOrder(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreateVipOrderReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreateVipOrderResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CreateVipOrder(ctx, &moe.CreateVipOrderReq{UserId: req.UserId, PlanId: req.PlanId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CreateVipOrderResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.CreateVipOrderResp{
			BaseResp:        common.HandleRPCError(nil, "创建VIP订单成功"),
			NewAchievements: achievementUnlocksFromRPC(rpcResp.NewAchievements),
			Data:            vipOrderFromRPC(rpcResp.Order),
		})
	}
}

func getVipHistory(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetVipHistoryReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetVipHistoryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetVipRecords(ctx, &moe.GetVipRecordsReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetVipHistoryResp{
				BaseResp: common.HandleRPCError(err, ""), Data: nil, Total: 0,
			})
		}
		records := make([]types.VipRecord, 0, len(rpcResp.Records))
		for _, rec := range rpcResp.Records {
			records = append(records, vipRecordFromRPC(rec))
		}
		return ctx.JSON(http.StatusOK, types.GetVipHistoryResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP历史记录成功"), Data: records, Total: int(rpcResp.Total),
		})
	}
}

func errEmptyEmail() error {
	return &paramError{msg: "邮箱不能为空"}
}

func errEmptyPassword() error {
	return &paramError{msg: "新密码不能为空"}
}

type paramError struct{ msg string }

func (e *paramError) Error() string { return e.msg }
