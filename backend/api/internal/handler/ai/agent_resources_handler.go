package ai

import (
	"errors"
	"net/http"

	ailogic "backend/api/internal/logic/ai"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ListAgentsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.ListAgents(userID)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func UpsertAgentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		resp, err := l.UpsertAgent(userID, req.Data)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func DeleteAgentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := parseUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		id := r.URL.Query().Get("id")
		if id == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing agent id"))
			return
		}
		l := ailogic.NewResourceLogic(r.Context(), svcCtx)
		resp, err := l.DeleteAgent(userID, id)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
