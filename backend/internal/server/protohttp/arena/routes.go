package arenahttp

import (
	"encoding/json"
	"net/http"

	arenabiz "backend/internal/biz/arena"
	apicomm "backend/internal/platform/apicomm"
	arenaapp "backend/internal/service/arena"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterRoutes 注册星辉远征 REST（/api/arena/*）。
func RegisterRoutes(s *khttp.Server, app *arenaapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.GET("/api/arena/state", wrap(app, handleGetState))
	r.PUT("/api/arena/formation", wrap(app, handleSetFormation))
	r.PUT("/api/arena/deck", wrap(app, handleSaveDeck))
	r.PUT("/api/arena/meta", wrap(app, handleSaveMeta))
	r.PUT("/api/arena/skin", wrap(app, handleSetSkin))
	r.POST("/api/arena/summon", wrap(app, handleSummon))
	r.POST("/api/arena/home/gift", wrap(app, handleHomeGift))
	r.POST("/api/arena/home/train", wrap(app, handleHomeTrain))
	r.POST("/api/arena/tower/clear", wrap(app, handleClearTower))
}

type handlerFunc func(app *arenaapp.AppService, ctx khttp.Context) error

func wrap(app *arenaapp.AppService, h handlerFunc) func(khttp.Context) error {
	return func(ctx khttp.Context) error { return h(app, ctx) }
}

func writeOK(ctx khttp.Context, data any) error {
	return ctx.Result(http.StatusOK, map[string]any{"code": 0, "msg": "ok", "data": data})
}

func writeErr(ctx khttp.Context, status int, msg string) error {
	return ctx.Result(status, map[string]any{"code": status, "msg": msg})
}

func actorID(ctx khttp.Context) (string, error) {
	return apicomm.UserIDString(ctx.Request().Context())
}

func handleGetState(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	st, err := app.GetState(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusInternalServerError, err.Error())
	}
	return writeOK(ctx, st)
}

type formationBody struct {
	HeroIDs []string `json:"hero_ids"`
}

func handleSetFormation(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body formationBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	st, err := app.SetFormation(ctx.Request().Context(), uid, body.HeroIDs)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, st)
}

type deckBody struct {
	Cards []arenabiz.DeckCard `json:"cards"`
}

func handleSaveDeck(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body deckBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	st, err := app.SaveDeck(ctx.Request().Context(), uid, body.Cards)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, st)
}

type metaBody struct {
	SelectedTowerNode *int `json:"selected_tower_node"`
	ClearBuffs        bool `json:"clear_buffs"`
}

func handleSaveMeta(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body metaBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	st, err := app.SaveMeta(ctx.Request().Context(), uid, body.SelectedTowerNode, body.ClearBuffs)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, st)
}

type skinBody struct {
	HeroID string `json:"hero_id"`
	SkinID string `json:"skin_id"`
}

func handleSetSkin(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body skinBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	st, err := app.SetSkin(ctx.Request().Context(), uid, body.HeroID, body.SkinID)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, st)
}

type summonBody struct {
	Count int `json:"count"`
}

func handleSummon(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body summonBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	res, err := app.Summon(ctx.Request().Context(), uid, body.Count)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, res)
}

type giftBody struct {
	HeroID string `json:"hero_id"`
}

func handleHomeGift(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body giftBody
	if err := json.NewDecoder(ctx.Request().Body).Decode(&body); err != nil {
		return writeErr(ctx, http.StatusBadRequest, "bad json")
	}
	st, err := app.HomeGift(ctx.Request().Context(), uid, body.HeroID)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, st)
}

func handleHomeTrain(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	st, err := app.HomeTrain(ctx.Request().Context(), uid)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, st)
}

type clearTowerBody struct {
	Won         bool                `json:"won"`
	BonusHeroID string              `json:"bonus_hero_id"`
	Deck        []arenabiz.DeckCard `json:"deck"`
}

func handleClearTower(app *arenaapp.AppService, ctx khttp.Context) error {
	uid, err := actorID(ctx)
	if err != nil || uid == "" {
		return writeErr(ctx, http.StatusUnauthorized, "unauthorized")
	}
	var body clearTowerBody
	_ = json.NewDecoder(ctx.Request().Body).Decode(&body)
	res, err := app.ClearTower(ctx.Request().Context(), uid, body.Won, body.BonusHeroID, body.Deck)
	if err != nil {
		return writeErr(ctx, http.StatusBadRequest, err.Error())
	}
	return writeOK(ctx, res)
}
