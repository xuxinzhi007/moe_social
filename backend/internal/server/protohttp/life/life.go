package lifehttp

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"

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
	r.GET("/api/life/relationships", getRelationshipsHandler(app))
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

// GET /api/life/relationships?world=default — 社交关系列表
func getRelationshipsHandler(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		engine := app.Engine()
		if engine == nil {
			return writeJSON(ctx, http.StatusServiceUnavailable, map[string]string{"error": "engine not ready"})
		}
		worldName := ctx.Request().URL.Query().Get("world")
		if worldName == "" {
			worldName = engine.GetConfig().WorldName
		}
		// 优先从内存缓存读取
		snap := engine.GetWorldCache().Get(worldName)
		if snap != nil {
			return writeJSON(ctx, http.StatusOK, snap.Relationships)
		}
		// 回退到 DB 读取
		store := app.Store()
		if store == nil {
			return writeJSON(ctx, http.StatusServiceUnavailable, map[string]string{"error": "store not ready"})
		}
		rels, err := store.ListRelationshipsByWorld(ctx.Request().Context(), worldName)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return writeJSON(ctx, http.StatusOK, rels)
	}
}

// POST /api/life/action — 用户操作端点（feed/pet/move）
func actionHandler(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		engine := app.Engine()
		if engine == nil {
			return writeJSON(ctx, http.StatusServiceUnavailable, map[string]string{"error": "engine not ready"})
		}

		var req struct {
			Action   string                 `json:"action"`
			EntityID uint                   `json:"entity_id"`
			Params   map[string]interface{} `json:"params"`
		}
		if err := json.NewDecoder(ctx.Request().Body).Decode(&req); err != nil {
			return writeJSON(ctx, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		}

		if req.Action == "" {
			return writeJSON(ctx, http.StatusBadRequest, map[string]string{"error": "action is required"})
		}
		if req.EntityID == 0 {
			return writeJSON(ctx, http.StatusBadRequest, map[string]string{"error": "entity_id is required"})
		}

		worldName := engine.GetConfig().WorldName
		result := engine.ApplyUserAction(worldName, req.EntityID, req.Action, req.Params)

		if !result.Success {
			// 冷却错误返回 HTTP 429
			if strings.Contains(result.Message, "cooldown") {
				retryAfter := extractRetrySeconds(result.Message)
				return writeJSON(ctx, http.StatusTooManyRequests, map[string]interface{}{
					"ok":          false,
					"error":       "action in cooldown",
					"retry_after": retryAfter,
				})
			}
			return writeJSON(ctx, http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"message": result.Message,
			})
		}

		return writeJSON(ctx, http.StatusOK, map[string]interface{}{
			"success": true,
			"message": result.Message,
			"entity":  result.Entity,
		})
	}
}

func writeJSON(ctx khttp.Context, status int, data interface{}) error {
	ctx.Response().Header().Set("Content-Type", "application/json")
	ctx.Response().WriteHeader(status)
	return json.NewEncoder(ctx.Response()).Encode(data)
}

// extractRetrySeconds 从冷却错误消息中提取剩余秒数
func extractRetrySeconds(msg string) float64 {
	// 消息格式: "action in cooldown, retry after X seconds"
	var seconds float64
	if _, err := fmt.Sscanf(msg, "action in cooldown, retry after %f seconds", &seconds); err == nil {
		if seconds < 1 {
			return 1
		}
		return math.Ceil(seconds)
	}
	return 3 // 解析失败时返回默认冷却时间
}
