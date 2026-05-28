package moekratospilot

import (
	"net/http"
	"strconv"

	"backend/api/internal/common"
	"backend/api/internal/types"
	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterAdminInsightsCompat Admin Insights 只读 HTTP（PK-3，:19032 与 :8888 同路径）。
func RegisterAdminInsightsCompat(srv *khttp.Server, app *adminapp.AppService) {
	if srv == nil || app == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/admin/ai/chat/sessions", adminListAiChatSessions(app))
	r.GET("/api/admin/ai/chat/messages", adminListAiChatMessages(app))
	r.GET("/api/admin/ai/chat/messages/export", adminExportAiChatMessages(app))
	r.GET("/api/admin/analytics/overview", adminAnalyticsOverview(app))
	r.GET("/api/admin/topic-tags", adminListTopicTags(app))
}

func adminListAiChatSessions(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		page, _ := strconv.Atoi(q.Get("page"))
		pageSize, _ := strconv.Atoi(q.Get("page_size"))
		rpcResp, err := app.ListAiChatSessions(ctx, &moe.AdminListAiChatSessionsReq{
			Page: int32(page), PageSize: int32(pageSize),
			UserId: q.Get("user_id"), SessionId: q.Get("session_id"),
			From: q.Get("from"), To: q.Get("to"),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAiChatSessionsResp{BaseResp: common.HandleError(err)})
		}
		items := make([]types.AdminAiChatSessionItem, 0, len(rpcResp.GetItems()))
		for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAiChatSessionToTypes(row))
		}
		return ctx.JSON(http.StatusOK, types.AdminListAiChatSessionsResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AdminListAiChatSessionsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminListAiChatMessages(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		page, _ := strconv.Atoi(q.Get("page"))
		pageSize, _ := strconv.Atoi(q.Get("page_size"))
		rpcResp, err := app.ListAiChatMessages(ctx, &moe.AdminListAiChatMessagesReq{
			Page: int32(page), PageSize: int32(pageSize),
			UserId: q.Get("user_id"), SessionId: q.Get("session_id"),
			Role: q.Get("role"), Keyword: q.Get("keyword"),
			From: q.Get("from"), To: q.Get("to"),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListAiChatMessagesResp{BaseResp: common.HandleError(err)})
		}
		items := make([]types.AdminAiChatMessageItem, 0, len(rpcResp.GetItems()))
		for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAiChatMessageToTypes(row))
		}
		return ctx.JSON(http.StatusOK, types.AdminListAiChatMessagesResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AdminListAiChatMessagesData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminExportAiChatMessages(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		limit, _ := strconv.Atoi(q.Get("limit"))
		rpcResp, err := app.ExportAiChatMessages(ctx, &moe.AdminExportAiChatMessagesReq{
			UserId: q.Get("user_id"), SessionId: q.Get("session_id"),
			Role: q.Get("role"), Keyword: q.Get("keyword"),
			From: q.Get("from"), To: q.Get("to"),
			Limit: int32(limit),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminExportAiChatMessagesResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminExportAiChatMessagesResp{
			BaseResp: common.HandleError(nil),
			Data: types.AdminExportAiChatMessagesData{
				Csv: rpcResp.GetCsv(), RowCount: int(rpcResp.GetRowCount()), Truncated: rpcResp.GetTruncated(),
			},
		})
	}
}

func adminAnalyticsOverview(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rpcResp, err := app.AnalyticsOverview(ctx, &moe.AdminGetMemoryStatsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminAnalyticsOverviewResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminAnalyticsOverviewResp{
			BaseResp: common.HandleError(nil),
			Data:     common.RpcAdminAnalyticsOverviewToTypes(rpcResp),
		})
	}
}

func adminListTopicTags(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		page, _ := strconv.Atoi(q.Get("page"))
		pageSize, _ := strconv.Atoi(q.Get("page_size"))
		rpcResp, err := app.ListTopicTags(ctx, &moe.AdminListTopicTagsReq{
			Page: int32(page), PageSize: int32(pageSize), Keyword: q.Get("keyword"),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListTopicTagsResp{BaseResp: common.HandleError(err)})
		}
		items := make([]types.TopicTag, 0, len(rpcResp.GetItems()))
		for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcTopicTagToTypes(row))
		}
		return ctx.JSON(http.StatusOK, types.AdminListTopicTagsResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AdminListTopicTagsData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}
