package moehttp

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	achievementapp "backend/internal/service/achievement"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeAchievementCompatRoutes 成就域 Kratos HTTP。
const PilotNativeAchievementCompatRoutes = 4

// RegisterAchievementCompat 用户成就 HTTP → internal/service/achievement。
func RegisterAchievementCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.AchievementApp == nil {
		return
	}
	app := svcCtx.AchievementApp
	r := srv.Route("/")
	r.GET("/api/user/:user_id/achievements", getUserAchievements(app))
	r.GET("/api/user/:user_id/achievements/unlocked", getUserUnlockedAchievements(app))
	r.GET("/api/user/:user_id/achievements/summary", getUserAchievementSummary(app))
	r.POST("/api/user/:user_id/achievements/ensure", ensureUserAchievements(app))
}

func getUserAchievements(app *achievementapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserAchievementsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserAchievements(ctx, &moe.GetUserAchievementsReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		return ctx.JSON(http.StatusOK, types.GetUserAchievementsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取成就列表成功", Success: true},
			Data:     achievementBadgesFromRPC(rpcResp.GetBadges()),
		})
	}
}

func getUserUnlockedAchievements(app *achievementapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserUnlockedAchievementsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserUnlockedAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserUnlockedAchievements(ctx, &moe.GetUserUnlockedAchievementsReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserUnlockedAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		return ctx.JSON(http.StatusOK, types.GetUserUnlockedAchievementsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取已解锁成就成功", Success: true},
			Data:     achievementBadgesFromRPC(rpcResp.GetBadges()),
		})
	}
}

func getUserAchievementSummary(app *achievementapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserAchievementSummaryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserAchievementSummaryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserAchievementSummary(ctx, &moe.GetUserAchievementSummaryReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserAchievementSummaryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		s := rpcResp.GetSummary()
		return ctx.JSON(http.StatusOK, types.GetUserAchievementSummaryResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取成就概览成功", Success: true},
			Data: types.AchievementSummary{
				TotalBadges:          int(s.GetTotalBadges()),
				UnlockedBadges:       int(s.GetUnlockedBadges()),
				CompletionPercentage: s.GetCompletionPercentage(),
			},
		})
	}
}

func ensureUserAchievements(app *achievementapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EnsureUserAchievementsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.EnsureUserAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.EnsureUserAchievements(ctx, &moe.EnsureUserAchievementsReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.EnsureUserAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		return ctx.JSON(http.StatusOK, types.EnsureUserAchievementsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "成就初始化成功", Success: true},
			Data: types.EnsureUserAchievementsData{
				NewAchievements: achievementUnlocksFromRPC(rpcResp.GetNewAchievements()),
			},
		})
	}
}
