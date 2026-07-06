package lifehttp

import (
	"encoding/json"
	"net/http"
	"strconv"

	lifeapp "backend/internal/service/life"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// Register 注册 LifeEngine REST 路由（不走 Proto 注册器）
func Register(app *lifeapp.AppService, srv *khttp.Server) {
	if app == nil || srv == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/life/world", getWorldHandler(app))
	r.GET("/api/life/entities", getEntitiesHandler(app))
	r.GET("/api/life/events", getEventsHandler(app))
	r.POST("/api/life/action", actionHandler(app))
}

// GET /api/life/world — 世界状态（优先从内存缓存读取）
func getWorldHandler(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		engine := app.Engine()
		if engine == nil {
			return writeJSON(ctx, http.StatusServiceUnavailable, map[string]string{"error": "engine not ready"})
		}
		snap := engine.GetWorldCache().Get(engine.GetConfig().WorldName)
		if snap == nil {
			return writeJSON(ctx, http.StatusNotFound, map[string]string{"error": "world not found"})
		}
		return writeJSON(ctx, http.StatusOK, map[string]interface{}{
			"world":        snap.World,
			"tick_count":   snap.TickCount,
			"entity_count": len(snap.Entities),
			"summary":      snap.Summary,
		})
	}
}

// GET /api/life/entities — 实体列表
func getEntitiesHandler(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		engine := app.Engine()
		if engine == nil {
			return writeJSON(ctx, http.StatusServiceUnavailable, map[string]string{"error": "engine not ready"})
		}
		snap := engine.GetWorldCache().Get(engine.GetConfig().WorldName)
		if snap == nil {
			return writeJSON(ctx, http.StatusOK, []interface{}{})
		}
		entities := make([]interface{}, 0, len(snap.Entities))
		for _, e := range snap.Entities {
			entities = append(entities, e)
		}
		return writeJSON(ctx, http.StatusOK, entities)
	}
}

// GET /api/life/events?limit=50 — 事件日志（从 DB 读取）
func getEventsHandler(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		store := app.Store()
		if store == nil {
			return writeJSON(ctx, http.StatusServiceUnavailable, map[string]string{"error": "store not ready"})
		}
		limitStr := ctx.Request().URL.Query().Get("limit")
		limit := 50
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 200 {
			limit = l
		}
		logs, err := store.ListRecentEventLogs(ctx.Request().Context(), "default", limit)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return writeJSON(ctx, http.StatusOK, logs)
	}
}

// POST /api/life/action — 用户操作（预留，暂返回 501）
func actionHandler(_ *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		return writeJSON(ctx, http.StatusNotImplemented, map[string]string{"message": "action endpoint reserved for future use"})
	}
}

func writeJSON(ctx khttp.Context, status int, data interface{}) error {
	ctx.Response().Header().Set("Content-Type", "application/json")
	ctx.Response().WriteHeader(status)
	return json.NewEncoder(ctx.Response()).Encode(data)
}
