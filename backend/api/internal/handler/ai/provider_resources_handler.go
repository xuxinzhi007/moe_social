package ai

import (
	"errors"
	"net/http"

	ailogic "backend/api/internal/logic/ai"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ListProvidersHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.ListProviders(userID)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func UpsertProviderHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		var req types.AiResourceUpsertReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.UpsertProvider(userID, req.Data)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func DeleteProviderHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		id := r.URL.Query().Get("id")
		if id == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing provider id"))
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.DeleteProvider(userID, id)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
