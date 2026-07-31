package pethttp

import (
	"encoding/json"
	"net/http"

	"backend/internal/apilegacy/common"
	petbiz "backend/internal/biz/pet"
	petapp "backend/internal/service/pet"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterRoutes 注册养成 REST（/api/pet/*）。
func RegisterRoutes(s *khttp.Server, app *petapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.GET("/api/pet/state", wrap(app, handleGet))
	r.POST("/api/pet/feed", wrap(app, handleFeed))
	r.POST("/api/pet/care", wrap(app, handleCare))
	r.POST("/api/pet/dress", wrap(app, handleDress))
	r.POST("/api/pet/scene", wrap(app, handleScene))
	r.POST("/api/pet/furniture", wrap(app, handleFurniture))
	r.POST("/api/pet/study", wrap(app, handleStudy))
	r.POST("/api/pet/work", wrap(app, handleWork))
	r.POST("/api/pet/age-up", wrap(app, handleAgeUp))
	r.POST("/api/pet/friend", wrap(app, handleFriend))
	r.POST("/api/pet/marry", wrap(app, handleMarry))
	r.POST("/api/pet/baby", wrap(app, handleBaby))
	r.POST("/api/pet/adventure", wrap(app, handleAdventure))
	r.POST("/api/pet/shop/buy", wrap(app, handleBuy))
	r.POST("/api/pet/iap/verify", wrap(app, handleIapVerify))
}

type handlerFunc func(app *petapp.AppService, ctx khttp.Context) error

func wrap(app *petapp.AppService, h handlerFunc) func(khttp.Context) error {
	return func(ctx khttp.Context) error { return h(app, ctx) }
}

func writeOK(ctx khttp.Context, data any) error {
	return ctx.Result(http.StatusOK, map[string]any{"code": 0, "msg": "ok", "data": data})
}

func writeErr(ctx khttp.Context, status int, msg string) error {
	return ctx.Result(status, map[string]any{"code": status, "msg": msg})
}

func actorID(ctx khttp.Context) (string, error) {
	return common.UserIDString(ctx.Request().Context())
}

func handleGet(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, err := app.Get(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusInternalServerError, err.Error())
	}
	return writeOK(ctx, p)
}

func handleFeed(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, err := app.Feed(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

func handleCare(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, err := app.Pet(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

type dressBody struct {
	Hat         string          `json:"hat_id"`
	Top         string          `json:"top_id"`
	Bottom      string          `json:"bottom_id"`
	Shoes       string          `json:"shoes_id"`
	WearLayout  json.RawMessage `json:"wear_layout"`
	OutfitJSON  json.RawMessage `json:"outfit_json"`
}

func handleDress(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body dressBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	outfit := string(body.OutfitJSON)
	if len(body.WearLayout) > 0 {
		outfit = string(body.WearLayout)
	}
	p, err := app.Dress(ctx.Request().Context(), uid, body.Hat, body.Top, body.Bottom, body.Shoes, outfit)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

type sceneBody struct {
	Scene string `json:"scene_id"`
}

func handleScene(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body sceneBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	p, err := app.SetScene(ctx.Request().Context(), uid, body.Scene)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

type furnitureBody struct {
	Slots []petbiz.FurnitureSlot `json:"slots"`
}

func handleFurniture(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body furnitureBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	p, err := app.PlaceFurniture(ctx.Request().Context(), uid, body.Slots)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

type studyBody struct {
	Subject string `json:"subject"`
}

func handleStudy(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body studyBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	p, msg, err := app.Study(ctx.Request().Context(), uid, body.Subject)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, map[string]any{"profile": p, "message": msg})
}

func handleWork(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, msg, err := app.Work(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, map[string]any{"profile": p, "message": msg})
}

func handleAgeUp(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, err := app.AgeUp(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

type friendBody struct {
	FriendID string `json:"friend_id"`
}

func handleFriend(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body friendBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	if err := app.AddFriend(ctx.Request().Context(), uid, body.FriendID); err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, map[string]string{"ok": "1"})
}

type marryBody struct {
	SpouseID string `json:"spouse_id"`
}

func handleMarry(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body marryBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	p, err := app.Marry(ctx.Request().Context(), uid, body.SpouseID)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

func handleBaby(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, err := app.HaveBaby(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

func handleAdventure(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	p, msg, win, err := app.Adventure(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, map[string]any{"profile": p, "message": msg, "win": win})
}

type buyBody struct {
	ItemID string `json:"item_id"`
}

func handleBuy(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body buyBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	p, err := app.BuySoft(ctx.Request().Context(), uid, body.ItemID)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, p)
}

type iapBody struct {
	ProductID string `json:"product_id"`
	Receipt   string `json:"receipt"`
}

// handleIapVerify P4 占位：未接商店验签前，用软通货礼包模拟发货。
func handleIapVerify(app *petapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body iapBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	if body.ProductID == "" {
		body.ProductID = "hat_vip_star"
	}
	p, err := app.BuySoft(ctx.Request().Context(), uid, body.ProductID)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, map[string]any{
		"profile":     p,
		"verified":    false,
		"placeholder": true,
		"message":     "iap placeholder: soft grant until store receipt verify",
	})
}
