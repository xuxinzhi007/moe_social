package companionhttp

import (
	"net/http"
	"strings"

	companionapp "backend/internal/service/companion"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterHeroSummaryRoute 注册 O4 登录快进摘要端点（只读，水位线幂等前移）。
func RegisterHeroSummaryRoute(s *khttp.Server, app *companionapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.GET("/api/companion/hero/summary", func(ctx khttp.Context) error {
		return handleHeroSummary(ctx, app)
	})
}

func handleHeroSummary(ctx khttp.Context, app *companionapp.AppService) error {
	r := ctx.Request()
	userID, err := actorUserID(r.Context())
	if err != nil {
		return err
	}
	heroSlug := strings.TrimSpace(r.URL.Query().Get("hero_slug"))
	if heroSlug == "" {
		return kerrors.BadRequest("HERO_REQUIRED", "缺少英雄标识")
	}

	summary, err := app.HeroOfflineSummary(r.Context(), userID, heroSlug)
	if err != nil {
		return err
	}
	if summary == nil {
		return ctx.Result(http.StatusOK, map[string]any{"generated": false})
	}
	return ctx.Result(http.StatusOK, map[string]any{
		"generated":     true,
		"summary":       summary.Text,
		"offline_hours": summary.OfflineHours,
		"event_count":   summary.EventCount,
	})
}
