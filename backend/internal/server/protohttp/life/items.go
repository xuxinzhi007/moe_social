package lifehttp

import (
	"encoding/json"
	"net/http"
	"sort"
	"time"

	lifeapp "backend/internal/service/life"
	"backend/model"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterItemRoutes 注册道具相关的自定义 REST 路由
func RegisterItemRoutes(s *khttp.Server, app *lifeapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.GET("/api/life/inventory", handleGetInventory(app))
	r.POST("/api/life/use-item", handleUseItem(app))
	r.POST("/api/life/items/claim", handleClaimItems(app))
	r.GET("/api/life/items/claim/status", handleClaimStatus(app))
	r.GET("/api/life/items", handleListItems(app))
}

// inventoryItemResponse 背包道具响应（含道具定义信息）
type inventoryItemResponse struct {
	ItemID      uint   `json:"item_id"`
	Name        string `json:"name"`
	Icon        string `json:"icon"`
	Description string `json:"description"`
	Quantity    int    `json:"quantity"`
}

// handleGetInventory GET /api/life/inventory
func handleGetInventory(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := actorUserIDString(ctx.Request().Context())
		if err != nil {
			return err
		}

		inventory, err := app.Store().GetInventory(ctx.Request().Context(), userID)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}

		var result []inventoryItemResponse
		for _, inv := range inventory {
			item, ok := app.Engine().GetItemSystem().GetItemDefinition(inv.ItemID)
			if !ok {
				continue
			}
			result = append(result, inventoryItemResponse{
				ItemID:      inv.ItemID,
				Name:        item.Name,
				Icon:        item.Icon,
				Description: item.Description,
				Quantity:    inv.Quantity,
			})
		}
		if result == nil {
			result = []inventoryItemResponse{}
		}
		return writeJSON(ctx, http.StatusOK, map[string]interface{}{"items": result})
	}
}

// useItemRequest 使用道具请求体
type useItemRequest struct {
	EntityID uint `json:"entity_id"`
	ItemID   uint `json:"item_id"`
}

// handleUseItem POST /api/life/use-item
func handleUseItem(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := actorUserIDString(ctx.Request().Context())
		if err != nil {
			return err
		}

		var req useItemRequest
		if err := json.NewDecoder(ctx.Request().Body).Decode(&req); err != nil {
			return writeJSON(ctx, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		}
		if req.EntityID == 0 || req.ItemID == 0 {
			return writeJSON(ctx, http.StatusBadRequest, map[string]string{"error": "entity_id and item_id are required"})
		}

		worldName := app.Engine().GetConfig().WorldName
		if err := app.Engine().UseItem(worldName, userID, req.EntityID, req.ItemID); err != nil {
			return writeJSON(ctx, http.StatusBadRequest, map[string]string{"error": err.Error()})
		}

		return writeJSON(ctx, http.StatusOK, map[string]string{"message": "item used successfully"})
	}
}

// handleClaimStatus GET /api/life/items/claim/status
func handleClaimStatus(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := actorUserIDString(ctx.Request().Context())
		if err != nil {
			return err
		}
		today := time.Now().Format("2006-01-02")
		claimed, err := app.Store().HasDailyClaim(ctx.Request().Context(), userID, today)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return writeJSON(ctx, http.StatusOK, map[string]interface{}{
			"claimed_today": claimed,
			"claim_date":    today,
		})
	}
}

// handleClaimItems POST /api/life/items/claim — 每日签到领取补给（每用户每天一次）。
func handleClaimItems(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		reqCtx := ctx.Request().Context()
		userID, err := actorUserIDString(reqCtx)
		if err != nil {
			return err
		}
		today := time.Now().Format("2006-01-02")
		claimed, err := app.Store().HasDailyClaim(reqCtx, userID, today)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		if claimed {
			return writeJSON(ctx, http.StatusOK, map[string]interface{}{
				"success":         true,
				"already_claimed": true,
				"claimed_today":   true,
				"claim_date":      today,
				"message":         "今日已签到领取过了",
				"items":           []inventoryItemResponse{},
				"count":           0,
			})
		}

		rewards := pickDailyClaimItems(app.Engine().GetItemSystem().ListAllItems())
		if len(rewards) == 0 {
			return writeJSON(ctx, http.StatusOK, map[string]interface{}{
				"success":         false,
				"already_claimed": false,
				"claimed_today":   false,
				"claim_date":      today,
				"message":         "暂无可用道具，请稍后再试",
				"items":           []inventoryItemResponse{},
				"count":           0,
				"error":           "暂无可用道具，请稍后再试",
			})
		}

		// 先占坑，避免并发双领；发放失败时仍算今日已签到（避免刷领）。
		created, err := app.Store().MarkDailyClaim(reqCtx, userID, today, 0)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		if !created {
			return writeJSON(ctx, http.StatusOK, map[string]interface{}{
				"success":         true,
				"already_claimed": true,
				"claimed_today":   true,
				"claim_date":      today,
				"message":         "今日已签到领取过了",
				"items":           []inventoryItemResponse{},
				"count":           0,
			})
		}

		granted := make([]inventoryItemResponse, 0, len(rewards))
		for _, item := range rewards {
			if item == nil {
				continue
			}
			if err := app.Store().GrantItem(reqCtx, userID, item.ID, 1); err != nil {
				return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			}
			granted = append(granted, inventoryItemResponse{
				ItemID:      item.ID,
				Name:        item.Name,
				Icon:        item.Icon,
				Description: item.Description,
				Quantity:    1,
			})
		}
		_ = app.Store().UpdateDailyClaimCount(reqCtx, userID, today, len(granted))

		return writeJSON(ctx, http.StatusOK, map[string]interface{}{
			"success":         true,
			"already_claimed": false,
			"claimed_today":   true,
			"claim_date":      today,
			"message":         "签到成功，补给已放入背包",
			"items":           granted,
			"count":           len(granted),
		})
	}
}

// pickDailyClaimItems 每日补给：每种常用类型各取 1 个（食物/药剂/玩具），不够则按 ID 补足最多 3 个。
func pickDailyClaimItems(all []*model.LifeItem) []*model.LifeItem {
	if len(all) == 0 {
		return nil
	}
	sorted := append([]*model.LifeItem(nil), all...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].ID < sorted[j].ID })

	byType := map[string]*model.LifeItem{}
	for _, item := range sorted {
		if item == nil {
			continue
		}
		t := item.ItemType
		if t != "food" && t != "medicine" && t != "toy" {
			continue
		}
		if _, ok := byType[t]; !ok {
			byType[t] = item
		}
	}
	out := make([]*model.LifeItem, 0, 3)
	for _, t := range []string{"food", "medicine", "toy"} {
		if item, ok := byType[t]; ok {
			out = append(out, item)
		}
	}
	if len(out) > 0 {
		return out
	}
	// 兜底：前 3 个定义
	limit := 3
	if len(sorted) < limit {
		limit = len(sorted)
	}
	return sorted[:limit]
}

// handleListItems GET /api/life/items
func handleListItems(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, err := actorUserIDString(ctx.Request().Context()); err != nil {
			return err
		}
		items := app.Engine().GetItemSystem().ListAllItems()
		return writeJSON(ctx, http.StatusOK, map[string]interface{}{"items": items})
	}
}

// writeJSON 辅助函数：写入 JSON 响应
func writeJSON(ctx khttp.Context, status int, data interface{}) error {
	ctx.Response().Header().Set("Content-Type", "application/json")
	ctx.Response().WriteHeader(status)
	return json.NewEncoder(ctx.Response()).Encode(data)
}
