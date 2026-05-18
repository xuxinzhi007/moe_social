package ai

import (
	"errors"
	"net/http"

	ailogic "backend/api/internal/logic/ai"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ListLorebooksHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.ListLorebooks(userID)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func UpsertLorebookHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		var req types.AiLorebookUpsertReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.UpsertLorebook(userID, req.Data, req.Entries)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func DeleteLorebookHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		id := r.URL.Query().Get("id")
		if id == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing lorebook id"))
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.DeleteLorebook(userID, id)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
