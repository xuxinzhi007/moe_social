package userhttp

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	userbiz "backend/internal/biz/user"
	userapp "backend/internal/service/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const maxAvatarPackRevisionBodyBytes = 8 << 20

type avatarPackRevisionUpsertRequest struct {
	Manifest  json.RawMessage `json:"manifest"`
	Artifacts json.RawMessage `json:"artifacts"`
}

type avatarPackRevisionResponse struct {
	UserID    string          `json:"user_id"`
	PackID    string          `json:"pack_id"`
	Version   string          `json:"version"`
	Manifest  json.RawMessage `json:"manifest"`
	Artifacts json.RawMessage `json:"artifacts"`
	CreatedAt string          `json:"created_at"`
	UpdatedAt string          `json:"updated_at"`
}

// RegisterAvatarPackRoutes 注册角色包版本持久化 REST 路由。
func RegisterAvatarPackRoutes(s *khttp.Server, app *userapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.PUT("/api/avatar/packs/{pack_id}/versions/{version}", func(ctx khttp.Context) error {
		return handleUpsertAvatarPackRevision(ctx, app)
	})
	r.GET("/api/avatar/packs/{pack_id}/versions/{version}", func(ctx khttp.Context) error {
		return handleGetAvatarPackRevision(ctx, app)
	})
	r.GET("/api/avatar/packs/{pack_id}", func(ctx khttp.Context) error {
		return handleGetLatestAvatarPackRevision(ctx, app)
	})
}

func handleUpsertAvatarPackRevision(ctx khttp.Context, app *userapp.AppService) error {
	userID, err := actorUserID(ctx.Request().Context())
	if err != nil {
		return ctx.JSON(http.StatusUnauthorized, map[string]any{"error": "unauthorized"})
	}
	packID := strings.TrimSpace(ctx.Vars().Get("pack_id"))
	version := strings.TrimSpace(ctx.Vars().Get("version"))
	if packID == "" || version == "" {
		return ctx.JSON(http.StatusBadRequest, map[string]any{"error": "pack_id and version are required"})
	}
	var req avatarPackRevisionUpsertRequest
	ctx.Request().Body = http.MaxBytesReader(ctx.Response(), ctx.Request().Body, maxAvatarPackRevisionBodyBytes)
	if err := json.NewDecoder(ctx.Request().Body).Decode(&req); err != nil {
		return ctx.JSON(http.StatusBadRequest, map[string]any{"error": "invalid request body"})
	}
	item, err := app.UpsertAvatarPackRevision(ctx.Request().Context(), userID, packID, version, req.Manifest, req.Artifacts)
	if err != nil {
		return avatarPackError(ctx, err)
	}
	return ctx.JSON(http.StatusOK, avatarPackRevisionResponseFromItem(item))
}

func handleGetAvatarPackRevision(ctx khttp.Context, app *userapp.AppService) error {
	userID, err := actorUserID(ctx.Request().Context())
	if err != nil {
		return ctx.JSON(http.StatusUnauthorized, map[string]any{"error": "unauthorized"})
	}
	packID := strings.TrimSpace(ctx.Vars().Get("pack_id"))
	version := strings.TrimSpace(ctx.Vars().Get("version"))
	if packID == "" || version == "" {
		return ctx.JSON(http.StatusBadRequest, map[string]any{"error": "pack_id and version are required"})
	}
	item, err := app.GetAvatarPackRevision(ctx.Request().Context(), userID, packID, version)
	if err != nil {
		return avatarPackError(ctx, err)
	}
	return ctx.JSON(http.StatusOK, avatarPackRevisionResponseFromItem(item))
}

func handleGetLatestAvatarPackRevision(ctx khttp.Context, app *userapp.AppService) error {
	userID, err := actorUserID(ctx.Request().Context())
	if err != nil {
		return ctx.JSON(http.StatusUnauthorized, map[string]any{"error": "unauthorized"})
	}
	packID := strings.TrimSpace(ctx.Vars().Get("pack_id"))
	if packID == "" {
		return ctx.JSON(http.StatusBadRequest, map[string]any{"error": "pack_id is required"})
	}
	item, err := app.GetLatestAvatarPackRevision(ctx.Request().Context(), userID, packID)
	if err != nil {
		return avatarPackError(ctx, err)
	}
	return ctx.JSON(http.StatusOK, avatarPackRevisionResponseFromItem(item))
}

func avatarPackRevisionResponseFromItem(item *userbiz.AvatarPackRevisionItem) avatarPackRevisionResponse {
	if item == nil {
		return avatarPackRevisionResponse{}
	}
	return avatarPackRevisionResponse{
		UserID:    item.UserID,
		PackID:    item.PackID,
		Version:   item.Version,
		Manifest:  item.Manifest,
		Artifacts: item.Artifacts,
		CreatedAt: item.CreatedAt,
		UpdatedAt: item.UpdatedAt,
	}
}

func avatarPackError(ctx khttp.Context, err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, userbiz.ErrNotFound):
		return ctx.JSON(http.StatusNotFound, map[string]any{"error": err.Error()})
	case errors.Is(err, userbiz.ErrInvalidArgument):
		return ctx.JSON(http.StatusBadRequest, map[string]any{"error": err.Error()})
	case errors.Is(err, userbiz.ErrUnauthorized):
		return ctx.JSON(http.StatusUnauthorized, map[string]any{"error": err.Error()})
	default:
		return ctx.JSON(http.StatusInternalServerError, map[string]any{"error": err.Error()})
	}
}
