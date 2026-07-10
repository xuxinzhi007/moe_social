package lifehttp

import (
	"encoding/json"
	"net/http"

	lifeapp "backend/internal/service/life"

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
		userID := "default_user" // MVP 硬编码

		inventory, err := app.Store().GetInventory(ctx.Request().Context(), userID)
		if err != nil {
			return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}

		// 合并道具定义信息
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
		userID := "default_user" // MVP 硬编码

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

// handleClaimItems POST /api/life/items/claim
func handleClaimItems(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID := "default_user" // MVP 硬编码

		items := app.Engine().GetItemSystem().ListAllItems()
		for _, item := range items {
			if err := app.Store().GrantItem(ctx.Request().Context(), userID, item.ID, 1); err != nil {
				return writeJSON(ctx, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			}
		}

		return writeJSON(ctx, http.StatusOK, map[string]interface{}{
			"message": "daily items claimed",
			"count":   len(items),
		})
	}
}

// handleListItems GET /api/life/items
func handleListItems(app *lifeapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
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
