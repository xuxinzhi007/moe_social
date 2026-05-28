package moekratospilot

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	landingapp "backend/internal/service/landing"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeLandingCompatRoutes Landing 域 Kratos 原生 HTTP（internal/service，PK-10 首批）。
const PilotNativeLandingCompatRoutes = 3

// RegisterLandingCompat Landing 反馈 HTTP → landingapp（不经 goctl handler）。
func RegisterLandingCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	app := svcCtx.LandingApp
	if app == nil {
		return
	}
	r := srv.Route("/")
	r.POST("/api/landing/feedback", landingSubmit(app))
	r.GET("/api/ops/landing/feedback", landingList(app, false))
	r.GET("/api/admin/landing/feedback", landingList(app, true))
}

func landingSubmit(app *landingapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SubmitLandingFeedbackReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SubmitLandingFeedbackResp{
				BaseResp: common.HandleError(err),
			})
		}
		source := strings.TrimSpace(req.Source)
		if source == "" {
			source = "official-site"
		}
		clientIP := common.ClientIPFromRequest(ctx.Request())
		_, err := app.Submit(ctx, &moe.SubmitLandingFeedbackReq{
			Email:     strings.TrimSpace(req.Email),
			Category:  strings.TrimSpace(req.Category),
			Content:   req.Content,
			Source:    source,
			ClientIp:  clientIP,
			UserAgent: ctx.Request().UserAgent(),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SubmitLandingFeedbackResp{
				BaseResp: common.HandleLandingGWError(err, ""),
			})
		}
		return ctx.JSON(http.StatusOK, types.SubmitLandingFeedbackResp{
			BaseResp: common.HandleLandingGWError(nil, "ok"),
		})
	}
}

func landingList(app *landingapp.AppService, requireAdmin bool) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if requireAdmin {
			if _, br := common.RequireAdminToken(ctx.Request()); br != nil {
				return ctx.JSON(http.StatusOK, types.ListLandingFeedbackResp{BaseResp: *br})
			}
		}
		var req types.ListLandingFeedbackReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ListLandingFeedbackResp{
				BaseResp: common.HandleError(err),
			})
		}
		page := req.Page
		if page <= 0 {
			page = 1
		}
		pageSize := req.PageSize
		if pageSize <= 0 {
			pageSize = 20
		}
		rpcResp, err := app.List(ctx, &moe.ListLandingFeedbackReq{
			Page:     int32(page),
			PageSize: int32(pageSize),
			Category: strings.TrimSpace(req.Category),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ListLandingFeedbackResp{
				BaseResp: common.HandleLandingGWError(err, ""),
			})
		}
		items := make([]types.LandingFeedbackItem, 0, len(rpcResp.GetItems()))
		for _, it := range rpcResp.GetItems() {
			if it == nil {
				continue
			}
			items = append(items, types.LandingFeedbackItem{
				Id:        it.GetId(),
				Email:     it.GetEmail(),
				Category:  it.GetCategory(),
				Content:   it.GetContent(),
				Source:    it.GetSource(),
				ClientIp:  it.GetClientIp(),
				UserAgent: it.GetUserAgent(),
				CreatedAt: it.GetCreatedAt(),
			})
		}
		return ctx.JSON(http.StatusOK, types.ListLandingFeedbackResp{
			BaseResp: common.HandleLandingGWError(nil, "ok"),
			Data: types.ListLandingFeedbackData{
				Items: items,
				Total: int(rpcResp.GetTotal()),
			},
		})
	}
}
