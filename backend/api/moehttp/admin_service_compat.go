package moehttp

import (
	"net/http"

	adminlogic "backend/api/internal/logic/admin"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeAdminServiceCompatRoutes Admin CRUD（logic 薄转；待内联 AdminApp.ListPosts 等）。
const PilotNativeAdminServiceCompatRoutes = 55

func RegisterAdminServiceCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.AdminApp == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/admin/accounts", adminListAccounts(svcCtx))
	r.POST("/api/admin/accounts", adminCreateAccount(svcCtx))
	r.PUT("/api/admin/accounts/:account_id", adminUpdateAccount(svcCtx))
	r.DELETE("/api/admin/accounts/:account_id", adminDeleteAccount(svcCtx))
	r.POST("/api/admin/achievements/bootstrap", adminBootstrapAchievements(svcCtx))
	r.GET("/api/admin/ai/agents", adminListAiAgents(svcCtx))
	r.DELETE("/api/admin/ai/agents", adminDeleteAiAgent(svcCtx))
	r.GET("/api/admin/announcements", adminListAnnouncements(svcCtx))
	r.POST("/api/admin/announcements", adminCreateAnnouncement(svcCtx))
	r.GET("/api/admin/announcements/:announcement_id", adminGetAnnouncement(svcCtx))
	r.PUT("/api/admin/announcements/:announcement_id", adminUpdateAnnouncement(svcCtx))
	r.DELETE("/api/admin/announcements/:announcement_id", adminDeleteAnnouncement(svcCtx))
	r.POST("/api/admin/announcements/:announcement_id/publish", adminPublishAnnouncement(svcCtx))
	r.GET("/api/admin/audit-logs", adminListAuditLogs(svcCtx))
	r.GET("/api/admin/comments", adminListComments(svcCtx))
	r.DELETE("/api/admin/comments/:comment_id", adminDeleteComment(svcCtx))
	r.GET("/api/admin/community/groups", adminListGroups(svcCtx))
	r.DELETE("/api/admin/community/groups/:group_id", adminDeleteGroup(svcCtx))
	r.GET("/api/admin/gifts", adminListGifts(svcCtx))
	r.POST("/api/admin/gifts", adminCreateGift(svcCtx))
	r.GET("/api/admin/gifts/:gift_id", adminGetGift(svcCtx))
	r.PUT("/api/admin/gifts/:gift_id", adminUpdateGift(svcCtx))
	r.DELETE("/api/admin/gifts/:gift_id", adminDeleteGift(svcCtx))
	r.POST("/api/admin/gifts/bootstrap", adminBootstrapGifts(svcCtx))
	r.POST("/api/admin/gifts/dedupe", adminDedupeGifts(svcCtx))
	r.GET("/api/admin/growth/achievements", adminListAchievements(svcCtx))
	r.PUT("/api/admin/growth/achievements/:achievement_id", adminUpdateAchievement(svcCtx))
	r.GET("/api/admin/growth/levels", adminListLevelConfigs(svcCtx))
	r.PUT("/api/admin/growth/levels/:level_id", adminUpdateLevelConfig(svcCtx))
	r.POST("/api/admin/growth/levels/bootstrap", adminBootstrapLevels(svcCtx))
	r.POST("/api/admin/notifications/broadcast", adminBroadcastNotification(svcCtx))
	r.POST("/api/admin/notifications/send", adminSendNotification(svcCtx))
	r.GET("/api/admin/orders/gift-purchase", adminListGiftPurchaseOrders(svcCtx))
	r.GET("/api/admin/orders/vip", adminListVipOrders(svcCtx))
	r.GET("/api/admin/post-reports", adminListPostReports(svcCtx))
	r.GET("/api/admin/posts", adminListPosts(svcCtx))
	r.DELETE("/api/admin/posts/:post_id", adminDeletePost(svcCtx))
	r.GET("/api/admin/social/follows", adminListFollows(svcCtx))
	r.DELETE("/api/admin/social/follows/:follow_id", adminDeleteFollow(svcCtx))
	r.GET("/api/admin/social/friend-requests", adminListFriendRequests(svcCtx))
	r.GET("/api/admin/tag-dictionary", adminListTagDictionary(svcCtx))
	r.POST("/api/admin/tag-dictionary", adminCreateTagDictionary(svcCtx))
	r.PUT("/api/admin/tag-dictionary/:entry_id", adminUpdateTagDictionary(svcCtx))
	r.DELETE("/api/admin/tag-dictionary/:entry_id", adminDeleteTagDictionary(svcCtx))
	r.PUT("/api/admin/topic-tags/:tag_id", adminUpdateTopicTag(svcCtx))
	r.DELETE("/api/admin/topic-tags/:tag_id", adminDeleteTopicTag(svcCtx))
	r.POST("/api/admin/topic-tags/bootstrap", adminBootstrapTopicTags(svcCtx))
	r.GET("/api/admin/users", adminListUsers(svcCtx))
	r.GET("/api/admin/users/:user_id", adminGetUser(svcCtx))
	r.PUT("/api/admin/users/:user_id", adminUpdateUser(svcCtx))
	r.GET("/api/admin/users/:user_id/profile", adminGetUserProfile(svcCtx))
	r.GET("/api/admin/vip/plans/:plan_id", adminGetVipPlan(svcCtx))
	r.PUT("/api/admin/vip/plans/:plan_id", adminUpdateVipPlan(svcCtx))
	r.DELETE("/api/admin/vip/plans/:plan_id", adminDeleteVipPlan(svcCtx))
	r.POST("/api/admin/vip/plans/bootstrap", adminBootstrapVipPlans(svcCtx))
}

func adminListAccounts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAccountsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListAccountsLogic(ctx, svcCtx)
		resp, err := l.AdminListAccounts(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/accounts", adminListAccounts(svcCtx))
func adminCreateAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateAccountReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminCreateAccountLogic(ctx, svcCtx)
		resp, err := l.AdminCreateAccount(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/accounts", adminCreateAccount(svcCtx))
func adminUpdateAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateAccountReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateAccountLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateAccount(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/accounts/:account_id", adminUpdateAccount(svcCtx))
func adminDeleteAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteAccountReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteAccountLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteAccount(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/accounts/:account_id", adminDeleteAccount(svcCtx))
func adminBootstrapAchievements(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminBootstrapAchievementsLogic(ctx, svcCtx)
		resp, err := l.AdminBootstrapAchievements(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/achievements/bootstrap", adminBootstrapAchievements(svcCtx))
func adminListAiAgents(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAiAgentsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListAiAgentsLogic(ctx, svcCtx)
		resp, err := l.AdminListAiAgents(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/ai/agents", adminListAiAgents(svcCtx))
func adminDeleteAiAgent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteAiAgentReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteAiAgentLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteAiAgent(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/ai/agents", adminDeleteAiAgent(svcCtx))
func adminListAnnouncements(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAnnouncementsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListAnnouncementsLogic(ctx, svcCtx)
		resp, err := l.AdminListAnnouncements(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/announcements", adminListAnnouncements(svcCtx))
func adminCreateAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateAnnouncementReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminCreateAnnouncementLogic(ctx, svcCtx)
		resp, err := l.AdminCreateAnnouncement(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/announcements", adminCreateAnnouncement(svcCtx))
func adminGetAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetAnnouncementReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminGetAnnouncementLogic(ctx, svcCtx)
		resp, err := l.AdminGetAnnouncement(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/announcements/:announcement_id", adminGetAnnouncement(svcCtx))
func adminUpdateAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateAnnouncementReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateAnnouncementLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateAnnouncement(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/announcements/:announcement_id", adminUpdateAnnouncement(svcCtx))
func adminDeleteAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteAnnouncementReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteAnnouncementLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteAnnouncement(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/announcements/:announcement_id", adminDeleteAnnouncement(svcCtx))
func adminPublishAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminPublishAnnouncementReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminPublishAnnouncementLogic(ctx, svcCtx)
		resp, err := l.AdminPublishAnnouncement(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/announcements/:announcement_id/publish", adminPublishAnnouncement(svcCtx))
func adminListAuditLogs(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAuditLogsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListAuditLogsLogic(ctx, svcCtx)
		resp, err := l.AdminListAuditLogs(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/audit-logs", adminListAuditLogs(svcCtx))
func adminListComments(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListCommentsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListCommentsLogic(ctx, svcCtx)
		resp, err := l.AdminListComments(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/comments", adminListComments(svcCtx))
func adminDeleteComment(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteCommentReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteCommentLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteComment(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/comments/:comment_id", adminDeleteComment(svcCtx))
func adminListGroups(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListGroupsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListGroupsLogic(ctx, svcCtx)
		resp, err := l.AdminListGroups(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/community/groups", adminListGroups(svcCtx))
func adminDeleteGroup(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteGroupLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteGroup(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/community/groups/:group_id", adminDeleteGroup(svcCtx))
func adminListGifts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListGiftsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListGiftsLogic(ctx, svcCtx)
		resp, err := l.AdminListGifts(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/gifts", adminListGifts(svcCtx))
func adminCreateGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminCreateGiftLogic(ctx, svcCtx)
		resp, err := l.AdminCreateGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/gifts", adminCreateGift(svcCtx))
func adminGetGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminGetGiftLogic(ctx, svcCtx)
		resp, err := l.AdminGetGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/gifts/:gift_id", adminGetGift(svcCtx))
func adminUpdateGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateGiftLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/gifts/:gift_id", adminUpdateGift(svcCtx))
func adminDeleteGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteGiftReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteGiftLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteGift(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/gifts/:gift_id", adminDeleteGift(svcCtx))
func adminBootstrapGifts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminBootstrapGiftsLogic(ctx, svcCtx)
		resp, err := l.AdminBootstrapGifts(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/gifts/bootstrap", adminBootstrapGifts(svcCtx))
func adminDedupeGifts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDedupeGiftsLogic(ctx, svcCtx)
		resp, err := l.AdminDedupeGifts(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/gifts/dedupe", adminDedupeGifts(svcCtx))
func adminListAchievements(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAchievementsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListAchievementsLogic(ctx, svcCtx)
		resp, err := l.AdminListAchievements(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/growth/achievements", adminListAchievements(svcCtx))
func adminUpdateAchievement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateAchievementReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateAchievementLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateAchievement(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/growth/achievements/:achievement_id", adminUpdateAchievement(svcCtx))
func adminListLevelConfigs(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListLevelConfigsLogic(ctx, svcCtx)
		resp, err := l.AdminListLevelConfigs(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/growth/levels", adminListLevelConfigs(svcCtx))
func adminUpdateLevelConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateLevelConfigReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateLevelConfigLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateLevelConfig(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/growth/levels/:level_id", adminUpdateLevelConfig(svcCtx))
func adminBootstrapLevels(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminBootstrapLevelsLogic(ctx, svcCtx)
		resp, err := l.AdminBootstrapLevels(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/growth/levels/bootstrap", adminBootstrapLevels(svcCtx))
func adminBroadcastNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminBroadcastNotificationReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminBroadcastNotificationLogic(ctx, svcCtx)
		resp, err := l.AdminBroadcastNotification(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/notifications/broadcast", adminBroadcastNotification(svcCtx))
func adminSendNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminSendNotificationReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminSendNotificationLogic(ctx, svcCtx)
		resp, err := l.AdminSendNotification(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/notifications/send", adminSendNotification(svcCtx))
func adminListGiftPurchaseOrders(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListGiftPurchaseOrdersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListGiftPurchaseOrdersLogic(ctx, svcCtx)
		resp, err := l.AdminListGiftPurchaseOrders(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/orders/gift-purchase", adminListGiftPurchaseOrders(svcCtx))
func adminListVipOrders(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListVipOrdersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListVipOrdersLogic(ctx, svcCtx)
		resp, err := l.AdminListVipOrders(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/orders/vip", adminListVipOrders(svcCtx))
func adminListPostReports(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListPostReportsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListPostReportsLogic(ctx, svcCtx)
		resp, err := l.AdminListPostReports(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/post-reports", adminListPostReports(svcCtx))
func adminListPosts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListPostsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListPostsLogic(ctx, svcCtx)
		resp, err := l.AdminListPosts(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/posts", adminListPosts(svcCtx))
func adminDeletePost(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeletePostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeletePostLogic(ctx, svcCtx)
		resp, err := l.AdminDeletePost(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/posts/:post_id", adminDeletePost(svcCtx))
func adminListFollows(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListFollowsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListFollowsLogic(ctx, svcCtx)
		resp, err := l.AdminListFollows(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/social/follows", adminListFollows(svcCtx))
func adminDeleteFollow(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteFollowReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteFollowLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteFollow(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/social/follows/:follow_id", adminDeleteFollow(svcCtx))
func adminListFriendRequests(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListFriendRequestsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListFriendRequestsLogic(ctx, svcCtx)
		resp, err := l.AdminListFriendRequests(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/social/friend-requests", adminListFriendRequests(svcCtx))
func adminListTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListTagDictionaryReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListTagDictionaryLogic(ctx, svcCtx)
		resp, err := l.AdminListTagDictionary(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/tag-dictionary", adminListTagDictionary(svcCtx))
func adminCreateTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateTagDictionaryReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminCreateTagDictionaryLogic(ctx, svcCtx)
		resp, err := l.AdminCreateTagDictionary(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/tag-dictionary", adminCreateTagDictionary(svcCtx))
func adminUpdateTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateTagDictionaryReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateTagDictionaryLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateTagDictionary(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/tag-dictionary/:entry_id", adminUpdateTagDictionary(svcCtx))
func adminDeleteTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteTagDictionaryReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteTagDictionaryLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteTagDictionary(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/tag-dictionary/:entry_id", adminDeleteTagDictionary(svcCtx))
func adminUpdateTopicTag(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateTopicTagReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateTopicTagLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateTopicTag(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/topic-tags/:tag_id", adminUpdateTopicTag(svcCtx))
func adminDeleteTopicTag(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteTopicTagReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteTopicTagLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteTopicTag(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/topic-tags/:tag_id", adminDeleteTopicTag(svcCtx))
func adminBootstrapTopicTags(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminBootstrapTopicTagsLogic(ctx, svcCtx)
		resp, err := l.AdminBootstrapTopicTags(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/topic-tags/bootstrap", adminBootstrapTopicTags(svcCtx))
func adminListUsers(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListUsersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminListUsersLogic(ctx, svcCtx)
		resp, err := l.AdminListUsers(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/users", adminListUsers(svcCtx))
func adminGetUser(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetUserReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminGetUserLogic(ctx, svcCtx)
		resp, err := l.AdminGetUser(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/users/:user_id", adminGetUser(svcCtx))
func adminUpdateUser(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateUserReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateUserLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateUser(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/users/:user_id", adminUpdateUser(svcCtx))
func adminGetUserProfile(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetUserProfileReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminGetUserProfileLogic(ctx, svcCtx)
		resp, err := l.AdminGetUserProfile(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/users/:user_id/profile", adminGetUserProfile(svcCtx))
func adminGetVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetVipPlanReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminGetVipPlanLogic(ctx, svcCtx)
		resp, err := l.AdminGetVipPlan(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.GET("/api/admin/vip/plans/:plan_id", adminGetVipPlan(svcCtx))
func adminUpdateVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateVipPlanReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminUpdateVipPlanLogic(ctx, svcCtx)
		resp, err := l.AdminUpdateVipPlan(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.PUT("/api/admin/vip/plans/:plan_id", adminUpdateVipPlan(svcCtx))
func adminDeleteVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteVipPlanReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminDeleteVipPlanLogic(ctx, svcCtx)
		resp, err := l.AdminDeleteVipPlan(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.DELETE("/api/admin/vip/plans/:plan_id", adminDeleteVipPlan(svcCtx))
func adminBootstrapVipPlans(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		l := adminlogic.NewAdminBootstrapVipPlansLogic(ctx, svcCtx)
		resp, err := l.AdminBootstrapVipPlans(&req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// register: r.POST("/api/admin/vip/plans/bootstrap", adminBootstrapVipPlans(svcCtx))
