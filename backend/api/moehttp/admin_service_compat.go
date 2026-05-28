package moehttp

import (
	"fmt"
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeAdminServiceCompatRoutes Admin CRUD（直挂 internal/service/admin + vip）。
const PilotNativeAdminServiceCompatRoutes = 55

func RegisterAdminServiceCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.AdminApp == nil {
		return
	}
	app := svcCtx.AdminApp
	r := srv.Route("/")
	r.GET("/api/admin/accounts", adminListAccounts(app))
	r.POST("/api/admin/accounts", adminCreateAccount(svcCtx))
	r.PUT("/api/admin/accounts/:account_id", adminUpdateAccount(svcCtx))
	r.DELETE("/api/admin/accounts/:account_id", adminDeleteAccount(svcCtx))
	r.POST("/api/admin/achievements/bootstrap", adminBootstrapAchievements(svcCtx))
	r.GET("/api/admin/ai/agents", adminListAiAgents(app))
	r.DELETE("/api/admin/ai/agents", adminDeleteAiAgent(svcCtx))
	r.GET("/api/admin/announcements", adminListAnnouncements(app))
	r.POST("/api/admin/announcements", adminCreateAnnouncement(svcCtx))
	r.GET("/api/admin/announcements/:announcement_id", adminGetAnnouncement(app))
	r.PUT("/api/admin/announcements/:announcement_id", adminUpdateAnnouncement(svcCtx))
	r.DELETE("/api/admin/announcements/:announcement_id", adminDeleteAnnouncement(svcCtx))
	r.POST("/api/admin/announcements/:announcement_id/publish", adminPublishAnnouncement(svcCtx))
	r.GET("/api/admin/audit-logs", adminListAuditLogs(app))
	r.GET("/api/admin/comments", adminListComments(app))
	r.DELETE("/api/admin/comments/:comment_id", adminDeleteComment(svcCtx))
	r.GET("/api/admin/community/groups", adminListGroups(app))
	r.DELETE("/api/admin/community/groups/:group_id", adminDeleteGroup(svcCtx))
	r.GET("/api/admin/gifts", adminListGifts(app))
	r.POST("/api/admin/gifts", adminCreateGift(svcCtx))
	r.GET("/api/admin/gifts/:gift_id", adminGetGift(app))
	r.PUT("/api/admin/gifts/:gift_id", adminUpdateGift(svcCtx))
	r.DELETE("/api/admin/gifts/:gift_id", adminDeleteGift(svcCtx))
	r.POST("/api/admin/gifts/bootstrap", adminBootstrapGifts(svcCtx))
	r.POST("/api/admin/gifts/dedupe", adminDedupeGifts(svcCtx))
	r.GET("/api/admin/growth/achievements", adminListAchievements(app))
	r.PUT("/api/admin/growth/achievements/:achievement_id", adminUpdateAchievement(svcCtx))
	r.GET("/api/admin/growth/levels", adminListLevelConfigs(app))
	r.PUT("/api/admin/growth/levels/:level_id", adminUpdateLevelConfig(svcCtx))
	r.POST("/api/admin/growth/levels/bootstrap", adminBootstrapLevels(svcCtx))
	r.POST("/api/admin/notifications/broadcast", adminBroadcastNotification(svcCtx))
	r.POST("/api/admin/notifications/send", adminSendNotification(svcCtx))
	r.GET("/api/admin/orders/gift-purchase", adminListGiftPurchaseOrders(app))
	r.GET("/api/admin/orders/vip", adminListVipOrders(app))
	r.GET("/api/admin/post-reports", adminListPostReports(app))
	r.GET("/api/admin/posts", adminListPosts(app))
	r.DELETE("/api/admin/posts/:post_id", adminDeletePost(svcCtx))
	r.GET("/api/admin/social/follows", adminListFollows(app))
	r.DELETE("/api/admin/social/follows/:follow_id", adminDeleteFollow(svcCtx))
	r.GET("/api/admin/social/friend-requests", adminListFriendRequests(app))
	r.GET("/api/admin/tag-dictionary", adminListTagDictionary(app))
	r.POST("/api/admin/tag-dictionary", adminCreateTagDictionary(svcCtx))
	r.PUT("/api/admin/tag-dictionary/:entry_id", adminUpdateTagDictionary(svcCtx))
	r.DELETE("/api/admin/tag-dictionary/:entry_id", adminDeleteTagDictionary(svcCtx))
	r.PUT("/api/admin/topic-tags/:tag_id", adminUpdateTopicTag(svcCtx))
	r.DELETE("/api/admin/topic-tags/:tag_id", adminDeleteTopicTag(svcCtx))
	r.POST("/api/admin/topic-tags/bootstrap", adminBootstrapTopicTags(svcCtx))
	r.GET("/api/admin/users", adminListUsers(app))
	r.GET("/api/admin/users/:user_id", adminGetUser(app))
	r.PUT("/api/admin/users/:user_id", adminUpdateUser(svcCtx))
	r.GET("/api/admin/users/:user_id/profile", adminGetUserProfile(app))
	r.GET("/api/admin/vip/plans/:plan_id", adminGetVipPlan(svcCtx))
	r.PUT("/api/admin/vip/plans/:plan_id", adminUpdateVipPlan(svcCtx))
	r.DELETE("/api/admin/vip/plans/:plan_id", adminDeleteVipPlan(svcCtx))
	r.POST("/api/admin/vip/plans/bootstrap", adminBootstrapVipPlans(svcCtx))
}

func adminListAccounts(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAccountsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListAccounts(ctx, &moe.AdminListAccountsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Keyword: req.Keyword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAccountsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminAccountItem, len(rpcResp.GetItems()))
		for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminAccountToTypes(item)
		}
		return ctx.JSON(http.StatusOK, types.AdminListAccountsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAccountsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminCreateAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateAccountReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.CreateAccount(ctx, &moe.AdminCreateAccountReq{
			Username: req.Username, Password: req.Password, Role: req.Role,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminCreateAccountResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminCreateAccountResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcAdminAccountToTypes(rpcResp.GetAccount()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "admin_account", resp.Data.Id, "创建管理员账号")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminUpdateAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateAccountReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcReq := &moe.AdminUpdateAccountReq{AccountId: req.AccountId}
		if username := strings.TrimSpace(req.Username); username != "" {
			rpcReq.Username = username
			rpcReq.UpdateUsername = true
		}
		if password := strings.TrimSpace(req.Password); password != "" {
			rpcReq.Password = password
			rpcReq.UpdatePassword = true
		}
		if role := strings.TrimSpace(req.Role); role != "" {
			rpcReq.Role = role
			rpcReq.UpdateRole = true
		}
		rpcResp, err := svcCtx.AdminApp.UpdateAccount(ctx, rpcReq)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAccountResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateAccountResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcAdminAccountToTypes(rpcResp.GetAccount()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "admin_account", req.AccountId, "更新管理员账号")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDeleteAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteAccountReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeleteAccount(ctx, &moe.AdminDeleteAccountReq{AccountId: req.AccountId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteAccountResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteAccountResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "admin_account", req.AccountId, "删除管理员账号")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminBootstrapAchievements(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.BootstrapAchievements(ctx, &moe.AdminBootstrapAchievementsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapAchievementsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		msg := "成就表已有数据，未导入"
		if rpcResp.GetCreated() > 0 {
			msg = "已导入默认成就定义"
		}
		resp := types.AdminBootstrapAchievementsResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapAchievementsData{Created: int(rpcResp.GetCreated())},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "achievement", "", "导入默认成就定义")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListAiAgents(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAiAgentsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListAiAgents(ctx, &moe.AdminListAiAgentsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Keyword: req.Keyword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAiAgentsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminAiAgentItem, 0, len(rpcResp.GetItems()))
		for _, item := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAiAgentToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.AdminListAiAgentsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAiAgentsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminDeleteAiAgent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteAiAgentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeleteAiAgent(ctx, &moe.AdminDeleteAiAgentReq{
			UserId: req.UserId, AgentId: req.AgentId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteAiAgentResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteAiAgentResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "ai_agent", req.AgentId, "删除 AI 分身")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListAnnouncements(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAnnouncementsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListAnnouncements(ctx, &moe.AdminListAnnouncementsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Keyword: req.Keyword, Status: req.Status,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAnnouncementsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminAnnouncementItem, 0, len(rpcResp.GetItems()))
		for _, item := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAnnouncementToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.AdminListAnnouncementsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAnnouncementsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminCreateAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateAnnouncementReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.CreateAnnouncement(ctx, &moe.AdminCreateAnnouncementReq{
			Title: req.Title, Content: req.Content,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminCreateAnnouncementResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminCreateAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "announcement", resp.Data.Id, "创建公告")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminGetAnnouncement(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetAnnouncementReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.GetAnnouncement(ctx, &moe.AdminGetAnnouncementReq{AnnouncementId: req.AnnouncementId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetAnnouncementResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
		})
	}
}

func adminUpdateAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateAnnouncementReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcReq := &moe.AdminUpdateAnnouncementReq{AnnouncementId: req.AnnouncementId}
		if title := strings.TrimSpace(req.Title); title != "" {
			rpcReq.Title = title
			rpcReq.UpdateTitle = true
		}
		if req.Content != "" {
			rpcReq.Content = req.Content
			rpcReq.UpdateContent = true
		}
		rpcResp, err := svcCtx.AdminApp.UpdateAnnouncement(ctx, rpcReq)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAnnouncementResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "announcement", req.AnnouncementId, "更新公告")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDeleteAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteAnnouncementReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeleteAnnouncement(ctx, &moe.AdminDeleteAnnouncementReq{AnnouncementId: req.AnnouncementId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteAnnouncementResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteAnnouncementResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "announcement", req.AnnouncementId, "删除公告")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminPublishAnnouncement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminPublishAnnouncementReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.PublishAnnouncement(ctx, &moe.AdminPublishAnnouncementReq{AnnouncementId: req.AnnouncementId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminPublishAnnouncementResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminPublishAnnouncementResp{
			BaseResp: common.HandleRPCError(nil, "发布成功"),
			Data:     common.RpcAdminAnnouncementToTypes(rpcResp.GetAnnouncement()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "publish", "announcement", req.AnnouncementId, "发布公告")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListAuditLogs(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAuditLogsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListAuditLogs(ctx, &moe.AdminListAuditLogsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize),
			Action: req.Action, Resource: req.Resource, AdminId: req.AdminId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAuditLogsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminAuditLogItem, 0, len(rpcResp.GetItems()))
		for _, item := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAuditLogToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.AdminListAuditLogsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAuditLogsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminListComments(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListCommentsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 50)
		rpcResp, err := app.ListComments(ctx, &moe.AdminListCommentsReq{
			Page: int32(page), PageSize: int32(pageSize), Keyword: req.Keyword, PostId: req.PostId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListCommentsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.Comment, 0, len(rpcResp.GetComments()))
		for _, c := range rpcResp.GetComments() {
			items = append(items, common.RpcCommentToTypes(c))
		}
		return ctx.JSON(http.StatusOK, types.AdminListCommentsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListCommentsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminDeleteComment(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteCommentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeleteComment(ctx, &moe.AdminDeleteCommentReq{CommentId: req.CommentId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteCommentResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteCommentResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "comment", req.CommentId, "删除评论")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListGroups(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListGroupsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 50)
		rpcResp, err := app.ListGroups(ctx, &moe.AdminListGroupsReq{
			Page: int32(page), PageSize: int32(pageSize), Keyword: req.Keyword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListGroupsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.Group, 0, len(rpcResp.GetGroups()))
		for _, g := range rpcResp.GetGroups() {
			items = append(items, common.RpcGroupToTypes(g))
		}
		return ctx.JSON(http.StatusOK, types.AdminListGroupsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListGroupsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminDeleteGroup(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteGroupReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeleteGroup(ctx, &moe.AdminDeleteGroupReq{GroupId: req.GroupId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteGroupResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteGroupResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "group", req.GroupId, "删除群组")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListGifts(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListGiftsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 50)
		rpcResp, err := app.AdminListGifts(ctx, &moe.AdminListGiftsReq{
			Page: int32(page), PageSize: int32(pageSize), Keyword: req.Keyword, Category: req.Category,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListGiftsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.Gift, 0, len(rpcResp.GetGifts()))
		for _, g := range rpcResp.GetGifts() {
			items = append(items, common.RpcGiftToTypes(g))
		}
		return ctx.JSON(http.StatusOK, types.AdminListGiftsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListGiftsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminCreateGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if strings.TrimSpace(req.Name) == "" {
			return ctx.JSON(http.StatusOK, types.AdminCreateGiftResp{
				BaseResp: types.BaseResp{Success: false, Message: "礼物名称不能为空"},
			})
		}
		if req.Price < 0 {
			return ctx.JSON(http.StatusOK, types.AdminCreateGiftResp{
				BaseResp: types.BaseResp{Success: false, Message: "价格不能为负数"},
			})
		}
		rpcResp, err := svcCtx.AdminApp.AdminCreateGift(ctx, &moe.AdminCreateGiftReq{
			Name: strings.TrimSpace(req.Name), Price: int32(req.Price), Icon: req.Icon,
			Description: req.Description, Category: req.Category, SortOrder: int32(req.SortOrder),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminCreateGiftResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminCreateGiftResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "gift", resp.Data.Id, "创建礼物")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminGetGift(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.AdminGetGift(ctx, &moe.AdminGetGiftReq{GiftId: req.GiftId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetGiftResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetGiftResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
		})
	}
}

func adminUpdateGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.AdminUpdateGift(ctx, &moe.AdminUpdateGiftReq{
			GiftId: req.GiftId, Name: req.Name, Price: int32(req.Price), Icon: req.Icon,
			Description: req.Description, Category: req.Category, SortOrder: int32(req.SortOrder),
			UpdateName: req.UpdateName, UpdatePrice: req.UpdatePrice, UpdateIcon: req.UpdateIcon,
			UpdateDescription: req.UpdateDescription, UpdateCategory: req.UpdateCategory, UpdateSortOrder: req.UpdateSortOrder,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateGiftResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateGiftResp{
			BaseResp: common.HandleRPCError(nil, "保存成功"),
			Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "gift", req.GiftId, "更新礼物")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDeleteGift(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteGiftReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.AdminDeleteGift(ctx, &moe.AdminDeleteGiftReq{GiftId: req.GiftId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteGiftResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteGiftResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "gift", req.GiftId, "删除礼物")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminBootstrapGifts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.AdminBootstrapGifts(ctx, &moe.AdminBootstrapGiftsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapGiftsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminBootstrapGiftsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminBootstrapGiftsData{Created: int(rpcResp.GetCreated())},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "gift", "", "导入默认礼物")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDedupeGifts(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.AdminDedupeGifts(ctx, &moe.AdminDedupeGiftsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDedupeGiftsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDedupeGiftsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminDedupeGiftsData{Removed: int(rpcResp.GetRemoved())},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "dedupe", "gift", "", "合并同名礼物")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListAchievements(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListAchievementsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListAchievements(ctx, &moe.AdminListAchievementsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Keyword: req.Keyword, Category: req.Category,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAchievementsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminAchievementItem, 0, len(rpcResp.GetItems()))
		for _, item := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAchievementToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.AdminListAchievementsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAchievementsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminUpdateAchievement(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateAchievementReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.UpdateAchievement(ctx, &moe.AdminUpdateAchievementReq{
			Id: req.AchievementId, Name: req.Name, Description: req.Description, Enabled: req.Enabled,
			ExpReward: int32(req.ExpReward), SortOrder: int32(req.SortOrder),
			UpdateName: req.UpdateName, UpdateDescription: req.UpdateDescription,
			UpdateEnabled: req.UpdateEnabled, UpdateExpReward: req.UpdateExpReward, UpdateSortOrder: req.UpdateSortOrder,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAchievementResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateAchievementResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminAchievementToTypes(rpcResp.GetItem()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "achievement", req.AchievementId, "更新成就定义")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListLevelConfigs(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListLevelConfigs(ctx, &moe.AdminListLevelConfigsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListLevelConfigsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminLevelConfigItem, len(rpcResp.GetItems()))
		for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminLevelConfigToTypes(item)
		}
		return ctx.JSON(http.StatusOK, types.AdminListLevelConfigsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
		})
	}
}

func adminUpdateLevelConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateLevelConfigReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.UpdateLevelConfig(ctx, &moe.AdminUpdateLevelConfigReq{
			Id: req.LevelId, Title: req.Title, MinExp: int32(req.MinExp), MaxExp: int32(req.MaxExp),
			Privileges: req.Privileges, BadgeUrl: req.BadgeUrl,
			UpdateTitle: req.UpdateTitle, UpdateMinExp: req.UpdateMinExp, UpdateMaxExp: req.UpdateMaxExp,
			UpdatePrivileges: req.UpdatePrivileges, UpdateBadgeUrl: req.UpdateBadgeUrl,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateLevelConfigResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateLevelConfigResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminLevelConfigToTypes(rpcResp.GetItem()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "level_config", fmt.Sprintf("%d", req.LevelId), "更新等级配置")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminBootstrapLevels(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.BootstrapLevels(ctx, &moe.AdminBootstrapLevelsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapLevelsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminBootstrapLevelsResp{
			BaseResp: common.HandleRPCError(nil, "初始化成功"),
			Data: types.AdminBootstrapLevelsData{
				LevelConfigsCreated:   int(rpcResp.GetLevelConfigsCreated()),
				CheckInRewardsCreated: int(rpcResp.GetCheckInRewardsCreated()),
			},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "level_config", "", "导入默认等级配置")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminBroadcastNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminBroadcastNotificationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.BroadcastNotification(ctx, &moe.AdminBroadcastNotificationReq{
			Title: req.Title, Content: req.Content,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBroadcastNotificationResp{BaseResp: common.HandleRPCError(err, "")})
		}
		wsSent := 0
		if svcCtx.ChatApp != nil {
			wsSent = svcCtx.ChatApp.BroadcastPushNotification(ctx, "system_notification", map[string]interface{}{
				"title": req.Title, "content": req.Content,
			})
		}
		resp := types.AdminBroadcastNotificationResp{
			BaseResp: common.HandleRPCError(nil, "广播成功"),
			Data: types.AdminBroadcastNotificationData{
				NotificationsCreated: int(rpcResp.GetNotificationsCreated()),
				WsSent:               wsSent,
			},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "broadcast", "notification", "", "广播通知")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminSendNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminSendNotificationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.SendNotification(ctx, &moe.AdminSendNotificationReq{
			UserId: req.UserId, Title: req.Title, Content: req.Content,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminSendNotificationResp{BaseResp: common.HandleRPCError(err, "")})
		}
		wsSent := false
		if svcCtx.ChatApp != nil {
			wsSent = svcCtx.ChatApp.PushNotification(ctx, req.UserId, "system_notification", map[string]interface{}{
				"title": req.Title, "content": req.Content,
			})
		}
		resp := types.AdminSendNotificationResp{
			BaseResp: common.HandleRPCError(nil, "发送成功"),
			Data: types.AdminSendNotificationData{
				NotificationId: rpcResp.GetNotificationId(),
				WsSent:         wsSent,
			},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "send", "notification", req.UserId, "发送用户通知")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListGiftPurchaseOrders(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListGiftPurchaseOrdersReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 50)
		rpcResp, err := app.ListGiftPurchaseOrders(ctx, &moe.AdminListGiftPurchaseOrdersReq{
			Page: int32(page), PageSize: int32(pageSize), UserId: req.UserId, Keyword: req.Keyword, Status: req.Status,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListGiftPurchaseOrdersResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.GiftPurchaseOrder, 0, len(rpcResp.GetOrders()))
		for _, o := range rpcResp.GetOrders() {
			items = append(items, common.RpcGiftPurchaseOrderToTypes(o))
		}
		return ctx.JSON(http.StatusOK, types.AdminListGiftPurchaseOrdersResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListGiftPurchaseOrdersData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminListVipOrders(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListVipOrdersReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 50)
		rpcResp, err := app.ListVipOrders(ctx, &moe.AdminListVipOrdersReq{
			Page: int32(page), PageSize: int32(pageSize), UserId: req.UserId, Keyword: req.Keyword, Status: req.Status,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListVipOrdersResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.VipOrder, 0, len(rpcResp.GetOrders()))
		for _, o := range rpcResp.GetOrders() {
			items = append(items, common.RpcVipOrderToTypes(o))
		}
		return ctx.JSON(http.StatusOK, types.AdminListVipOrdersResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListVipOrdersData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminListPostReports(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListPostReportsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 50)
		rpcResp, err := app.ListPostReports(ctx, &moe.AdminListPostReportsReq{
			Page: int32(page), PageSize: int32(pageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListPostReportsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminPostReportItem, 0, len(rpcResp.GetReports()))
		for _, r := range rpcResp.GetReports() {
			items = append(items, rpcAdminPostReportToTypes(r))
		}
		return ctx.JSON(http.StatusOK, types.AdminListPostReportsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListPostReportsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminListPosts(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListPostsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 20)
		rpcResp, err := app.ListPosts(ctx, &moe.AdminListPostsReq{
			Page: int32(page), PageSize: int32(pageSize), Keyword: req.Keyword,
			ModerationStatus: req.ModerationStatus, IncludeDeleted: req.IncludeDeleted,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListPostsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.Post, 0, len(rpcResp.GetPosts()))
		for _, p := range rpcResp.GetPosts() {
			items = append(items, common.RpcPostToTypes(p))
		}
		return ctx.JSON(http.StatusOK, types.AdminListPostsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListPostsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminDeletePost(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeletePostReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeletePost(ctx, &moe.AdminDeletePostReq{PostId: req.PostId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeletePostResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeletePostResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "post", req.PostId, "删除帖子")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListFollows(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListFollowsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListFollows(ctx, &moe.AdminListFollowsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Keyword: req.Keyword, UserId: req.UserId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListFollowsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminFollowItem, 0, len(rpcResp.GetItems()))
		for _, item := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminFollowToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.AdminListFollowsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListFollowsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminDeleteFollow(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteFollowReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := svcCtx.AdminApp.DeleteFollow(ctx, &moe.AdminDeleteFollowReq{FollowId: req.FollowId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteFollowResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteFollowResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "follow", req.FollowId, "删除关注关系")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListFriendRequests(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListFriendRequestsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListFriendRequests(ctx, &moe.AdminListFriendRequestsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Status: req.Status, Keyword: req.Keyword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListFriendRequestsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminFriendRequestItem, 0, len(rpcResp.GetItems()))
		for _, item := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminFriendRequestToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.AdminListFriendRequestsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListFriendRequestsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminListTagDictionary(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListTagDictionaryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListTagDictionary(ctx, &moe.AdminListTagDictionaryReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize), Category: req.Category, Keyword: req.Keyword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminTagDictionaryItem, 0, len(rpcResp.GetItems()))
		for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminTagDictionaryToTypes(row))
		}
		return ctx.JSON(http.StatusOK, types.AdminListTagDictionaryResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListTagDictionaryData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminCreateTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminCreateTagDictionaryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.CreateTagDictionary(ctx, &moe.AdminCreateTagDictionaryReq{
			Category: req.Category, Tag: req.Tag, Label: req.Label, Note: req.Note,
			SortOrder: int32(req.SortOrder), Enabled: req.Enabled,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminCreateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminCreateTagDictionaryResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcAdminTagDictionaryToTypes(rpcResp.GetItem()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "tag_dictionary", resp.Data.Id, "创建 Bot 策略标签")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminUpdateTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateTagDictionaryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		entryID, err := parseAdminPathID(req.EntryId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "条目 ID 无效")})
		}
		rpcResp, err := svcCtx.AdminApp.UpdateTagDictionary(ctx, &moe.AdminUpdateTagDictionaryReq{
			EntryId: entryID, Category: req.Category, Tag: req.Tag, Label: req.Label, Note: req.Note,
			SortOrder: int32(req.SortOrder), Enabled: req.Enabled, UpdateEnabled: req.UpdateEnabled,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateTagDictionaryResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcAdminTagDictionaryToTypes(rpcResp.GetItem()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "tag_dictionary", req.EntryId, "更新 Bot 策略标签")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDeleteTagDictionary(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteTagDictionaryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		entryID, err := parseAdminPathID(req.EntryId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(err, "条目 ID 无效")})
		}
		_, err = svcCtx.AdminApp.DeleteTagDictionary(ctx, &moe.AdminDeleteTagDictionaryReq{EntryId: entryID})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "tag_dictionary", req.EntryId, "删除 Bot 策略标签")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminUpdateTopicTag(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateTopicTagReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		tagID, err := parseAdminPathID(req.TagId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateTopicTagResp{BaseResp: common.HandleRPCError(err, "标签 ID 无效")})
		}
		rpcResp, err := svcCtx.AdminApp.UpdateTopicTag(ctx, &moe.AdminUpdateTopicTagReq{
			TagId: tagID, Name: req.Name, Color: req.Color,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateTopicTagResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateTopicTagResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcTopicTagToTypes(rpcResp.GetItem()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "topic_tag", req.TagId, "更新话题标签")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDeleteTopicTag(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteTopicTagReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		tagID, err := parseAdminPathID(req.TagId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(err, "标签 ID 无效")})
		}
		_, err = svcCtx.AdminApp.DeleteTopicTag(ctx, &moe.AdminDeleteTopicTagReq{TagId: tagID})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "topic_tag", req.TagId, "删除话题标签")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminBootstrapTopicTags(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.AdminBootstrapTopicTags(ctx, &moe.AdminBootstrapTopicTagsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapTopicTagsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		msg := "话题表已有数据，未导入"
		if rpcResp.GetCreated() > 0 {
			msg = "已导入官方话题标签"
		}
		resp := types.AdminBootstrapTopicTagsResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapTopicTagsData{Created: int(rpcResp.GetCreated())},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "topic_tag", "", "导入官方话题标签")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminListUsers(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminListUsersReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		page := adminPageOrDefault(req.Page, 1)
		pageSize := adminPageSizeOrDefault(req.PageSize, 20)
		rpcResp, err := app.ListUsers(ctx, &moe.AdminListUsersReq{
			Page: int32(page), PageSize: int32(pageSize), Keyword: req.Keyword,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListUsersResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.User, 0, len(rpcResp.GetUsers()))
		for _, u := range rpcResp.GetUsers() {
			items = append(items, common.RpcUserToTypes(u))
		}
		return ctx.JSON(http.StatusOK, types.AdminListUsersResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListUsersData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminGetUser(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetUserReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.GetUser(ctx, &moe.AdminGetUserReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetUserResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetUserResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcUserToTypes(rpcResp.GetUser()),
		})
	}
}

func adminUpdateUser(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateUserReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := svcCtx.AdminApp.UpdateUser(ctx, &moe.AdminUpdateUserReq{
			UserId: req.UserId, Role: req.Role, IsVip: req.IsVip, UpdateIsVip: req.UpdateIsVip,
			Signature: req.Signature, UpdateSignature: req.UpdateSignature,
			Avatar: req.Avatar, UpdateAvatar: req.UpdateAvatar,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateUserResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateUserResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcUserToTypes(rpcResp.GetUser()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "user", fmt.Sprintf("%d", req.UserId), "更新 App 用户")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminGetUserProfile(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetUserProfileReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.GetUserProfile(ctx, &moe.AdminGetUserProfileReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetUserProfileResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetUserProfileResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminUserProfileToTypes(rpcResp.GetData()),
		})
	}
}

func adminGetVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetVipPlanReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if svcCtx.VipAdmin == nil {
			return ctx.JSON(http.StatusOK, types.AdminGetVipPlanResp{
				BaseResp: common.HandleRPCError(fmt.Errorf("vip admin unavailable"), ""),
			})
		}
		rpcResp, err := svcCtx.VipAdmin.AdminGetVipPlan(ctx, &moe.AdminGetVipPlanReq{PlanId: req.PlanId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetVipPlanResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcVipPlanToTypes(rpcResp.GetPlan()),
		})
	}
}

func adminUpdateVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminUpdateVipPlanReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if svcCtx.VipAdmin == nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateVipPlanResp{
				BaseResp: common.HandleRPCError(fmt.Errorf("vip admin unavailable"), ""),
			})
		}
		rpcResp, err := svcCtx.VipAdmin.AdminUpdateVipPlan(ctx, &moe.AdminUpdateVipPlanReq{
			PlanId: req.PlanId, Name: req.Name, Description: req.Description, Price: float32(req.Price),
			DurationDays: int32(req.DurationDays),
			UpdateName:   req.UpdateName, UpdateDescription: req.UpdateDescription,
			UpdatePrice: req.UpdatePrice, UpdateDurationDays: req.UpdateDurationDays,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateVipPlanResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		resp := types.AdminUpdateVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcVipPlanToTypes(rpcResp.GetPlan()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "vip_plan", req.PlanId, "更新 VIP 套餐")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminDeleteVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminDeleteVipPlanReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if svcCtx.VipAdmin == nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteVipPlanResp{
				BaseResp: common.HandleRPCError(fmt.Errorf("vip admin unavailable"), ""),
			})
		}
		_, err := svcCtx.VipAdmin.AdminDeleteVipPlan(ctx, &moe.AdminDeleteVipPlanReq{PlanId: req.PlanId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteVipPlanResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		resp := types.AdminDeleteVipPlanResp{BaseResp: common.HandleRPCError(nil, "已删除")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "vip_plan", req.PlanId, "删除 VIP 套餐")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminBootstrapVipPlans(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if svcCtx.VipAdmin == nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapVipPlansResp{
				BaseResp: common.HandleRPCError(fmt.Errorf("vip admin unavailable"), ""),
			})
		}
		rpcResp, err := svcCtx.VipAdmin.AdminBootstrapVipPlans(ctx, &moe.AdminBootstrapVipPlansReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapVipPlansResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		msg := "ok"
		if rpcResp.GetCreated() > 0 {
			msg = "已导入默认套餐"
		} else {
			msg = "已有套餐，未导入"
		}
		resp := types.AdminBootstrapVipPlansResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapVipPlansData{Created: int(rpcResp.GetCreated())},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "vip_plan", "", "导入默认 VIP 套餐")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}
